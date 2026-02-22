import AppKit
import SwiftUI
import WhisperNotesLib

@main
struct WhisperNotesApp: App {
    @StateObject private var appState: AppState

    init() {
        if !Database.preflightCheck() {
            let alert = NSAlert()
            alert.messageText = "Cannot Initialize Database"
            alert.informativeText = "WhisperNotes cannot access its data directory in Application Support. "
                + "Please check disk permissions and available storage, then relaunch."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApp.terminate(nil)
        }
        _appState = StateObject(wrappedValue: AppState())
    }

    private var isFolderSelected: Bool {
        if case let .folder(id) = appState.sidebarSelection,
           id != SidebarSelection.uncategorizedFolderID
        {
            return appState.folders.contains { $0.id == id }
        }
        return false
    }

    private var favoriteMenuLabel: String {
        appState.selectedTranscription?.isFavorite == true
            ? "Remove from Favorites"
            : "Add to Favorites"
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 500)
                .sheet(isPresented: Binding(
                    get: { !appState.hasCompletedSetup },
                    set: { _ in }
                )) {
                    LanguageSetupView()
                        .environmentObject(appState)
                        .interactiveDismissDisabled()
                }
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

            CommandGroup(after: .pasteboard) {
                Button("Delete") {
                    appState.deleteSelectedItem()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(appState.selectedTranscription == nil && !isFolderSelected)
            }

            CommandGroup(before: .textEditing) {
                Button("Find") {
                    appState.searchFocusTrigger += 1
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Button(favoriteMenuLabel) {
                    appState.toggleFavoriteSelected()
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(appState.selectedTranscription == nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
