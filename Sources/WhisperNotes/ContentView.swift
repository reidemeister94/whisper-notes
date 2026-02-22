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
