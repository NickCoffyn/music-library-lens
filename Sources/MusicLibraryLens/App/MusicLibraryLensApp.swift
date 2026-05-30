import AppKit
import SwiftUI

@main
struct MusicLibraryLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = LibraryStore()

    var body: some Scene {
        WindowGroup("Music Library Lens") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1120, minHeight: 720)
                .task {
                    store.restoreSavedLibraryIfAvailable()
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Choose Music Folder...") {
                    store.presentLibraryPicker()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Import XML Library...") {
                    store.presentXMLPicker()
                }
                .keyboardShortcut("i", modifiers: [.command])

                Button("Rescan Library") {
                    store.rescanSelectedLibrary()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(store.libraryURL == nil || store.isScanning)

                Button("Stop Scan") {
                    store.cancelScan()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!store.isScanning)

                Button("Forget Folder") {
                    store.clearRememberedLibrary()
                }
                .disabled(store.libraryURL == nil && store.catalogTracks.isEmpty)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
