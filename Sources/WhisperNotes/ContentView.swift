import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var state: AppState

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
        } content: {
            TranscriptionListView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 400)
        } detail: {
            if let selected = state.selectedTranscription {
                TranscriptionDetailView(transcription: selected)
            } else {
                EmptyDetailView()
            }
        }
        .sheet(isPresented: $state.showRecording) {
            RecordingView()
        }
        .alert(
            "Delete Transcription",
            isPresented: Binding(
                get: { state.transcriptionToDelete != nil },
                set: { if !$0 { state.transcriptionToDelete = nil } }
            ),
            presenting: state.transcriptionToDelete
        ) { _ in
            Button("Delete", role: .destructive) {
                state.executeDeleteTranscription()
            }
            Button("Cancel", role: .cancel) {
                state.transcriptionToDelete = nil
            }
        } message: { transcription in
            Text("Delete \"\(transcription.title)\"? This cannot be undone.")
        }
        .alert(
            "Delete Folder",
            isPresented: Binding(
                get: { state.folderToDelete != nil },
                set: { if !$0 { state.folderToDelete = nil } }
            ),
            presenting: state.folderToDelete
        ) { _ in
            Button("Delete", role: .destructive) {
                state.executeDeleteFolder()
            }
            Button("Cancel", role: .cancel) {
                state.folderToDelete = nil
            }
        } message: { folder in
            Text("Delete folder \"\(folder.name)\"? Transcriptions will be moved to Uncategorized.")
        }
    }
}

struct EmptyDetailView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 80))
                .foregroundStyle(.quaternary)

            VStack(spacing: 8) {
                Text("Select a transcription")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Or start a new recording to transcribe audio with Whisper")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            Button {
                state.showRecording = true
            } label: {
                Label("New Recording", systemImage: "mic.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
