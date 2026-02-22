import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
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
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)
            Text("Select a transcription")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Or start a new recording")
                .font(.callout)
                .foregroundStyle(.tertiary)

            Button {
                state.showRecording = true
            } label: {
                Label("New Recording", systemImage: "mic.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
