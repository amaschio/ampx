import SwiftUI

/// App menu bar commands: File in the standard slot, View for panels + UI Scale, Playback for transport.
struct AmpXCommands: Commands {
    @ObservedObject var audioPlayer: AudioPlayer
    @ObservedObject var playlistManager: PlaylistManager
    @ObservedObject var uiScale: AmpXUIScale
    @ObservedObject var panelLayout: AmpXPanelLayoutState

    var body: some Commands {
        // Own the system File menu instead of CommandMenu("File") (which appends a second File).
        CommandGroup(replacing: .newItem) {
            Button(AmpXMenuCatalog.FileItem.addFiles.rawValue) {
                self.playlistManager.showFilePicker()
            }
            .keyboardShortcut(
                KeyEquivalent(Character(AmpXMenuCatalog.FileShortcut.addFilesKey)),
                modifiers: Self.fileModifiers(
                    command: AmpXMenuCatalog.FileShortcut.addFilesUsesCommand,
                    shift: AmpXMenuCatalog.FileShortcut.addFilesUsesShift
                )
            )
            Button(AmpXMenuCatalog.FileItem.addFolder.rawValue) {
                self.playlistManager.showFolderPicker()
            }
            .keyboardShortcut(
                KeyEquivalent(Character(AmpXMenuCatalog.FileShortcut.addFilesKey)),
                modifiers: Self.fileModifiers(
                    command: AmpXMenuCatalog.FileShortcut.addFolderUsesCommand,
                    shift: AmpXMenuCatalog.FileShortcut.addFolderUsesShift
                )
            )
            Divider()
            Button(AmpXMenuCatalog.FileItem.loadPlaylist.rawValue) {
                self.playlistManager.showLoadM3UPicker()
            }
            Button(AmpXMenuCatalog.FileItem.savePlaylist.rawValue) {
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
            Toggle(AmpXMenuCatalog.ViewPanel.equalizer.rawValue, isOn: self.$panelLayout.showEqualizer)
            Toggle(AmpXMenuCatalog.ViewPanel.playlist.rawValue, isOn: self.$panelLayout.showPlaylist)
            Toggle(AmpXMenuCatalog.ViewPanel.visualizer.rawValue, isOn: self.$panelLayout.showVisualizer)
            Divider()
            Menu(AmpXMenuCatalog.uiScaleMenuTitle) {
                ForEach(AmpXUIScaleLevel.allCases) { level in
                    Button(level.label) {
                        self.uiScale.setLevel(level)
                    }
                    .disabled(self.uiScale.level == level)
                }
            }
        }

        CommandMenu("Playback") {
            Button(AmpXMenuCatalog.PlaybackItem.playPause.rawValue) {
                self.audioPlayer.togglePlayPause()
            }
            .keyboardShortcut("x", modifiers: [])
            Button(AmpXMenuCatalog.PlaybackItem.stop.rawValue) {
                self.audioPlayer.stop()
            }
            .keyboardShortcut("v", modifiers: [])
            Button(AmpXMenuCatalog.PlaybackItem.previous.rawValue) {
                self.playlistManager.previous()
            }
            .keyboardShortcut("z", modifiers: [])
            Button(AmpXMenuCatalog.PlaybackItem.next.rawValue) {
                self.playlistManager.next()
            }
            .keyboardShortcut("b", modifiers: [])
            Divider()
            Toggle(AmpXMenuCatalog.PlaybackItem.shuffle.rawValue, isOn: self.$playlistManager.shuffleEnabled)
            Toggle(AmpXMenuCatalog.PlaybackItem.repeat.rawValue, isOn: self.$playlistManager.repeatEnabled)
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
