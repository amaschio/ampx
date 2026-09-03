import SwiftUI

/// App menu bar commands: File in the standard slot, View for panels + UI Scale, Playback for transport.
struct WinampCommands: Commands {
    @ObservedObject var audioPlayer: AudioPlayer
    @ObservedObject var playlistManager: PlaylistManager
    @ObservedObject var uiScale: WinampUIScale
    @ObservedObject var panelLayout: WinampPanelLayoutState

    var body: some Commands {
        // Own the system File menu instead of CommandMenu("File") (which appends a second File).
        CommandGroup(replacing: .newItem) {
            Button(WinampMenuCatalog.FileItem.addFiles.rawValue) {
                self.playlistManager.showFilePicker()
            }
            .keyboardShortcut(
                KeyEquivalent(Character(WinampMenuCatalog.FileShortcut.addFilesKey)),
                modifiers: Self.fileModifiers(
                    command: WinampMenuCatalog.FileShortcut.addFilesUsesCommand,
                    shift: WinampMenuCatalog.FileShortcut.addFilesUsesShift
                )
            )
            Button(WinampMenuCatalog.FileItem.addFolder.rawValue) {
                self.playlistManager.showFolderPicker()
            }
            .keyboardShortcut(
                KeyEquivalent(Character(WinampMenuCatalog.FileShortcut.addFilesKey)),
                modifiers: Self.fileModifiers(
                    command: WinampMenuCatalog.FileShortcut.addFolderUsesCommand,
                    shift: WinampMenuCatalog.FileShortcut.addFolderUsesShift
                )
            )
            Divider()
            Button(WinampMenuCatalog.FileItem.loadPlaylist.rawValue) {
                self.playlistManager.showLoadM3UPicker()
            }
            Button(WinampMenuCatalog.FileItem.savePlaylist.rawValue) {
                self.playlistManager.saveM3UPlaylist()
            }
            .disabled(self.playlistManager.tracks.isEmpty)
        }

        // Strip Edit clutter that doesn't apply to a skin-based player.
        CommandGroup(replacing: .undoRedo) {}
        CommandGroup(replacing: .pasteboard) {}
        CommandGroup(replacing: .textEditing) {}

        // Panel toggles + UI Scale live in View (before system toolbar / fullscreen items).
        CommandGroup(before: .toolbar) {
            Toggle(WinampMenuCatalog.ViewPanel.equalizer.rawValue, isOn: self.$panelLayout.showEqualizer)
            Toggle(WinampMenuCatalog.ViewPanel.playlist.rawValue, isOn: self.$panelLayout.showPlaylist)
            Toggle(WinampMenuCatalog.ViewPanel.visualizer.rawValue, isOn: self.$panelLayout.showVisualizer)
            Divider()
            Menu(WinampMenuCatalog.uiScaleMenuTitle) {
                ForEach(WinampUIScaleLevel.allCases) { level in
                    Button(level.label) {
                        self.uiScale.setLevel(level)
                    }
                    .disabled(self.uiScale.level == level)
                }
            }
        }

        CommandMenu("Playback") {
            Button(WinampMenuCatalog.PlaybackItem.playPause.rawValue) {
                self.audioPlayer.togglePlayPause()
            }
            .keyboardShortcut("x", modifiers: [])
            Button(WinampMenuCatalog.PlaybackItem.stop.rawValue) {
                self.audioPlayer.stop()
            }
            .keyboardShortcut("v", modifiers: [])
            Button(WinampMenuCatalog.PlaybackItem.previous.rawValue) {
                self.playlistManager.previous()
            }
            .keyboardShortcut("z", modifiers: [])
            Button(WinampMenuCatalog.PlaybackItem.next.rawValue) {
                self.playlistManager.next()
            }
            .keyboardShortcut("b", modifiers: [])
            Divider()
            Toggle(WinampMenuCatalog.PlaybackItem.shuffle.rawValue, isOn: self.$playlistManager.shuffleEnabled)
            Toggle(WinampMenuCatalog.PlaybackItem.repeat.rawValue, isOn: self.$playlistManager.repeatEnabled)
        }
    }

    private static func fileModifiers(command: Bool, shift: Bool) -> EventModifiers {
        var modifiers: EventModifiers = []
        if command {
            modifiers.insert(.command)
        }
        if shift {
            modifiers.insert(.shift)
        }
        return modifiers
    }
}
