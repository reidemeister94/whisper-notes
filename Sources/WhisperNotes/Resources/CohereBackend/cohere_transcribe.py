#!/usr/bin/env python3
"""Bundled Cohere Transcribe backend for WhisperNotes."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
import wave
from dataclasses import dataclass
from pathlib import Path


DEFAULT_MODEL_ID = "CohereLabs/cohere-transcribe-03-2026"
PROCESSOR_METADATA_KEYS = {"audio_chunk_index", "length"}


class AudioPreparationError(RuntimeError):
    """Raised when the input audio cannot be prepared for the model."""


class TranscriptionError(RuntimeError):
    """Raised when the model cannot produce a transcription."""


@dataclass
class PreparedAudio:
    path: Path
    temp_dir: tempfile.TemporaryDirectory[str] | None = None

    def cleanup(self) -> None:
        if self.temp_dir is not None:
            self.temp_dir.cleanup()
            self.temp_dir = None

    def __enter__(self) -> "PreparedAudio":
        return self

    def __exit__(self, exc_type, exc, traceback) -> None:
        self.cleanup()


class SpeechTranscriber:
    def __init__(
        self,
        *,
        language: str = "it",
        model_id: str = DEFAULT_MODEL_ID,
        device: str = "auto",
        punctuation: bool = True,
        max_new_tokens: int = 256,
    ) -> None:
        try:
            import torch
            from transformers import AutoProcessor
            from transformers.audio_utils import load_audio

            try:
                from transformers import (
                    CohereAsrForConditionalGeneration as model_class,
                )
            except ImportError:
                from transformers import AutoModelForSpeechSeq2Seq as model_class
        except ImportError as exc:
            raise TranscriptionError(
                "Dipendenze ML mancanti. Apri le impostazioni di WhisperNotes, "
                "seleziona Cohere Transcribe e segui il comando di setup mostrato."
            ) from exc

        self.language = language
        self.model_id = model_id
        self.punctuation = punctuation
        self.max_new_tokens = max_new_tokens
        self.torch = torch
        self.load_audio = load_audio
        self.resolved_device = resolve_device(torch, device)
        self.dtype = resolve_dtype(torch, self.resolved_device)

        try:
            self.processor = AutoProcessor.from_pretrained(
                model_id, trust_remote_code=True
            )
            self.model = model_class.from_pretrained(
                model_id,
                torch_dtype=self.dtype,
                trust_remote_code=True,
            )
        except Exception as exc:
            raise TranscriptionError(build_model_load_error(model_id, exc)) from exc

        self.model.to(self.resolved_device)
        self.model.eval()

    def transcribe_file(self, audio_path: Path) -> str:
        audio = self.load_audio(str(audio_path), sampling_rate=16000)
        return self.transcribe_waveform(audio, sampling_rate=16000)

    def transcribe_waveform(self, audio, *, sampling_rate: int = 16000) -> str:
        if sampling_rate != 16000:
            raise TranscriptionError("Il backend locale si aspetta audio a 16 kHz.")

        audio_chunks = split_audio(
            audio,
            sampling_rate=sampling_rate,
            chunk_seconds=resolve_chunk_seconds(self.processor, self.model),
        )

        try:
            inputs = self.processor(
                audio_chunks,
                sampling_rate=sampling_rate,
                return_tensors="pt",
                language=self.language,
                punctuation=self.punctuation,
            )
            audio_chunk_index = inputs.get("audio_chunk_index")
            inputs = inputs.to(
                self.resolved_device,
                dtype=getattr(self.model, "dtype", self.dtype),
            )
            generation_inputs = build_generation_inputs(inputs)

            with self.torch.inference_mode():
                outputs = self.model.generate(
                    **generation_inputs,
                    max_new_tokens=self.max_new_tokens,
                )

            decoded = decode_outputs(
                self.processor,
                outputs,
                audio_chunk_index=audio_chunk_index,
                language=self.language,
            )
        except Exception as exc:
            raise TranscriptionError(f"Trascrizione fallita: {exc}") from exc

        return normalize_decoded_text(decoded)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="cohere_transcribe.py",
        description="Backend locale di WhisperNotes per Cohere Transcribe.",
    )
    parser.add_argument("audio", type=Path, help="File audio da trascrivere.")
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL_ID,
        help=f"Modello Hugging Face da usare. Default: {DEFAULT_MODEL_ID}",
    )
    parser.add_argument("--language", default="it", help="Codice lingua. Default: it")
    parser.add_argument(
        "--device",
        choices=["auto", "mps", "cpu", "cuda"],
        default="auto",
        help="Device PyTorch. Default: auto, preferisce MPS su Apple Silicon.",
    )
    parser.add_argument(
        "--no-punctuation",
        action="store_true",
        help="Disabilita punteggiatura e maiuscole quando supportato dal modello.",
    )
    parser.add_argument(
        "--max-new-tokens",
        type=int,
        default=256,
        help="Massimo token generati per chunk audio. Default: 256.",
    )
    parser.add_argument(
        "--keep-wav",
        type=Path,
        help="Salva il WAV normalizzato 16 kHz mono in questo path.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        with prepare_audio(args.audio, keep_wav=args.keep_wav) as prepared_audio:
            print(f"Audio normalizzato: {prepared_audio.path}", file=sys.stderr)
            print(f"Carico modello: {args.model}", file=sys.stderr)
            text = transcribe_audio(
                prepared_audio.path,
                language=args.language,
                model_id=args.model,
                device=args.device,
                punctuation=not args.no_punctuation,
                max_new_tokens=args.max_new_tokens,
            )
    except (AudioPreparationError, TranscriptionError) as exc:
        print(f"Errore: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Interrotto.", file=sys.stderr)
        return 130

    print(text)
    return 0


def prepare_audio(input_path: Path, keep_wav: Path | None = None) -> PreparedAudio:
    source = input_path.expanduser().resolve()
    if not source.exists():
        raise AudioPreparationError(f"File audio non trovato: {source}")
    if not source.is_file():
        raise AudioPreparationError(f"Il path non e' un file audio: {source}")

    if source.suffix.lower() == ".wav" and is_compatible_wav(source):
        return PreparedAudio(path=source)

    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise AudioPreparationError(
            "ffmpeg non e' installato. Installa con Homebrew: brew install ffmpeg"
        )

    temp_dir = None
    if keep_wav is None:
        temp_dir = tempfile.TemporaryDirectory(prefix="whispernotes-cohere-")
        output_path = Path(temp_dir.name) / f"{source.stem}.16k-mono.wav"
    else:
        output_path = keep_wav.expanduser().resolve()
        if output_path == source:
            raise AudioPreparationError(
                "--keep-wav non puo' sovrascrivere il file sorgente"
            )
        output_path.parent.mkdir(parents=True, exist_ok=True)

    command = [
        ffmpeg,
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(source),
        "-ac",
        "1",
        "-ar",
        "16000",
        "-vn",
        str(output_path),
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        if temp_dir is not None:
            temp_dir.cleanup()
        detail = (
            result.stderr.strip() or "ffmpeg ha restituito un errore senza dettagli"
        )
        raise AudioPreparationError(f"Conversione audio fallita: {detail}")

    return PreparedAudio(path=output_path, temp_dir=temp_dir)


def is_compatible_wav(source: Path) -> bool:
    try:
        with wave.open(str(source), "rb") as wav_file:
            return (
                wav_file.getnchannels() == 1
                and wav_file.getframerate() == 16000
                and wav_file.getsampwidth() == 2
                and wav_file.getcomptype() == "NONE"
            )
    except (wave.Error, EOFError, OSError):
        return False


def transcribe_audio(
    audio_path: Path,
    *,
    language: str = "it",
    model_id: str = DEFAULT_MODEL_ID,
    device: str = "auto",
    punctuation: bool = True,
    max_new_tokens: int = 256,
) -> str:
    try:
        transcriber = SpeechTranscriber(
            language=language,
            model_id=model_id,
            device=device,
            punctuation=punctuation,
            max_new_tokens=max_new_tokens,
        )
        return transcriber.transcribe_file(audio_path)
    except Exception as exc:
        if isinstance(exc, TranscriptionError):
            raise
        raise TranscriptionError(f"Trascrizione fallita: {exc}") from exc


def resolve_device(torch_module, requested: str) -> str:
    if requested != "auto":
        if requested == "mps" and not torch_module.backends.mps.is_available():
            raise TranscriptionError(
                "Device MPS richiesto, ma non disponibile su questo Mac."
            )
        if requested == "cuda" and not torch_module.cuda.is_available():
            raise TranscriptionError("Device CUDA richiesto, ma non disponibile.")
        return requested

    if torch_module.backends.mps.is_available():
        return "mps"
    if torch_module.cuda.is_available():
        return "cuda"
    return "cpu"


def resolve_dtype(torch_module, device: str):
    if device in {"mps", "cuda"}:
        return torch_module.float16
    return torch_module.float32


def normalize_decoded_text(decoded) -> str:
    if isinstance(decoded, str):
        return decoded.strip()
    if isinstance(decoded, list):
        return "\n".join(str(part).strip() for part in decoded if str(part).strip())
    return str(decoded).strip()


def resolve_chunk_seconds(processor, model) -> float:
    candidates = [
        getattr(getattr(processor, "feature_extractor", None), "max_duration", None),
        getattr(getattr(model, "config", None), "max_audio_clip_s", None),
    ]
    positive_candidates = [
        float(value) for value in candidates if value and float(value) > 0
    ]
    if not positive_candidates:
        return 30.0
    return min(positive_candidates)


def split_audio(audio, *, sampling_rate: int, chunk_seconds: float) -> list:
    chunk_size = int(sampling_rate * chunk_seconds)
    if chunk_size <= 0 or len(audio) <= chunk_size:
        return [audio]
    return [
        audio[start : start + chunk_size] for start in range(0, len(audio), chunk_size)
    ]


def build_generation_inputs(inputs) -> dict:
    generation_inputs = {
        key: value
        for key, value in inputs.items()
        if key not in PROCESSOR_METADATA_KEYS
    }
    input_features = generation_inputs.get("input_features")
    if input_features is not None:
        generation_inputs["input_features"] = transpose_mel_features_if_needed(
            input_features
        )
        feature_shape = getattr(generation_inputs["input_features"], "shape", None)
        if feature_shape is not None and len(feature_shape) > 1:
            attention_mask = build_attention_mask(
                inputs.get("length"), max_length=feature_shape[1]
            )
            if attention_mask is not None:
                generation_inputs["attention_mask"] = attention_mask
    return generation_inputs


def transpose_mel_features_if_needed(input_features):
    if getattr(input_features, "ndim", 0) == 3 and input_features.shape[1] == 128:
        return input_features.transpose(1, 2).contiguous()
    return input_features


def build_attention_mask(lengths, *, max_length: int):
    if (
        lengths is None
        or not hasattr(lengths, "device")
        or not hasattr(lengths, "unsqueeze")
    ):
        return None

    import torch

    positions = torch.arange(max_length, device=lengths.device).unsqueeze(0)
    return positions < lengths.unsqueeze(1)


def decode_outputs(processor, outputs, *, audio_chunk_index, language: str):
    if getattr(outputs, "ndim", 0) > 1 and hasattr(processor, "batch_decode"):
        return processor.batch_decode(outputs, skip_special_tokens=True)

    decode_kwargs = {"skip_special_tokens": True}
    if audio_chunk_index is not None:
        decode_kwargs["audio_chunk_index"] = audio_chunk_index
        decode_kwargs["language"] = language

    try:
        return processor.decode(outputs, **decode_kwargs)
    except TypeError:
        if hasattr(processor, "batch_decode"):
            return processor.batch_decode(outputs, skip_special_tokens=True)
        return processor.decode(outputs, skip_special_tokens=True)


def build_model_load_error(model_id: str, exc: Exception) -> str:
    raw = str(exc)
    lower = raw.lower()
    if "gated" in lower or "401" in lower or "403" in lower or "unauthorized" in lower:
        return (
            f"Non riesco ad accedere a {model_id}. Accetta le condizioni del modello su "
            "Hugging Face, poi esegui hf auth login nel terminale."
        )
    return f"Caricamento modello fallito per {model_id}: {raw}"


if __name__ == "__main__":
    raise SystemExit(main())
