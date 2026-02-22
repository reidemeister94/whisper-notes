import SwiftUI

@main
struct WhisperNotesApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Recording") {
                    appState.showRecording = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("New Folder") {
                    appState.createFolder(name: "New Folder")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
