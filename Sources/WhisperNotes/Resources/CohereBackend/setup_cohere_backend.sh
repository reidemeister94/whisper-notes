#!/usr/bin/env bash
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SUPPORT="${WHISPER_NOTES_COHERE_HOME:-"$HOME/Library/Application Support/WhisperNotes/CohereBackend"}"
VENV_DIR="$APP_SUPPORT/venv"
PYTHON_BIN="${PYTHON:-python3}"

mkdir -p "$APP_SUPPORT"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Python non trovato. Installa Python 3.11+ o imposta PYTHON=/path/to/python." >&2
  exit 1
fi

"$PYTHON_BIN" - <<'PY'
import sys

if sys.version_info < (3, 11):
    raise SystemExit("Serve Python 3.11 o superiore.")
PY

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg non trovato. Installa con: brew install ffmpeg" >&2
  exit 1
fi

"$PYTHON_BIN" -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --upgrade pip uv
"$VENV_DIR/bin/python" -m uv pip install -r "$BACKEND_DIR/requirements.txt"

cat <<EOF
Cohere backend pronto.

Python da usare in WhisperNotes:
$VENV_DIR/bin/python

Se il modello richiede login Hugging Face, esegui:
hf auth login
EOF
