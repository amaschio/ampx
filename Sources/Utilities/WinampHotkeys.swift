import AppKit
import Foundation

/// Central key-down router for Pass-B Winamp hotkeys (global playback + playlist ops).
@MainActor
enum WinampHotkeys {
    private static let seekStep: TimeInterval = 5
    private static let volumeStep: Float = 0.05

    /// Returns `nil` when the event was handled (should be swallowed).
    static func handle(
        _ event: NSEvent,
        audioPlayer: AudioPlayer?,
        playlistManager: PlaylistManager?
    ) -> NSEvent? {
        guard let window = NSApp.keyWindow, window.isKeyWindow else { return event }

        if let firstResponder = window.firstResponder,
           firstResponder is NSTextView || firstResponder is NSTextField
        {
            return event
        }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let playlistFocused = WinampPanelWindowManager.shared.isPlaylistWindow(window)
            && WinampPlaylistKeyboard.isActive

        if playlistFocused,
           let handled = Self.handlePlaylistKey(
               event,
               flags: flags,
               playlistManager: playlistManager
           )
        {
            return handled
        }

        return Self.handleGlobalKey(
            event,
            flags: flags,
            audioPlayer: audioPlayer,
            playlistManager: playlistManager,
            playlistFocused: playlistFocused
        )
    }

    private static func handleGlobalKey(
        _ event: NSEvent,
        flags: NSEvent.ModifierFlags,
        audioPlayer: AudioPlayer?,
        playlistManager: PlaylistManager?,
        playlistFocused: Bool
    ) -> NSEvent? {
        let noMods = flags.isEmpty
        let key = event.keyCode

        if noMods, key == 49 { // Space
            audioPlayer?.togglePlayPause()
            return nil
        }

        if noMods {
            switch key {
            case 8: // C
                audioPlayer?.togglePlayPause()
                return nil
            case 15: // R
                playlistManager?.repeatEnabled.toggle()
                return nil
            case 1: // S
                playlistManager?.shuffleEnabled.toggle()
                return nil
            case 7: // X
                audioPlayer?.togglePlayPause()
                return nil
            case 9: // V
                audioPlayer?.stop()
                return nil
            case 6: // Z
                playlistManager?.previous()
                return nil
            case 11: // B
                playlistManager?.next()
                return nil
            case 37: // L
                playlistManager?.showFilePicker()
                return nil
            default:
                break
            }
        }

        if flags == [.shift], key == 37 {
            playlistManager?.showFolderPicker()
            return nil
        }

        if noMods, !playlistFocused {
            switch key {
            case 123:
                Self.seek(audioPlayer, by: -Self.seekStep)
                return nil
            case 124:
                Self.seek(audioPlayer, by: Self.seekStep)
                return nil
            case 126:
                Self.adjustVolume(audioPlayer, by: Self.volumeStep)
                return nil
            case 125:
                Self.adjustVolume(audioPlayer, by: -Self.volumeStep)
                return nil
            default:
                break
            }
        }

        return event
    }

    /// Returns `nil` if handled; `event` if this key is not a playlist binding (fall through to global).
    private static func handlePlaylistKey(
        _ event: NSEvent,
        flags: NSEvent.ModifierFlags,
        playlistManager: PlaylistManager?
    ) -> NSEvent? {
        let key = event.keyCode
        let shift = flags.contains(.shift)
        let command = flags.contains(.command)
        let option = flags.contains(.option)
        let control = flags.contains(.control)

        if control, !command { return event }

        if !command, !option, !control {
            switch key {
            case 126:
                WinampPlaylistKeyboard.moveSelection(by: -1, extend: shift)
                return nil
            case 125:
                WinampPlaylistKeyboard.moveSelection(by: 1, extend: shift)
                return nil
            case 115:
                WinampPlaylistKeyboard.jumpToStart(extend: shift)
                return nil
            case 119:
                WinampPlaylistKeyboard.jumpToEnd(extend: shift)
                return nil
            case 116:
                WinampPlaylistKeyboard.pageSelection(direction: -1, extend: shift)
                return nil
            case 121:
                WinampPlaylistKeyboard.pageSelection(direction: 1, extend: shift)
                return nil
            case 36:
                WinampPlaylistKeyboard.playSelectedTrack()
                return nil
            case 51, 117:
                WinampPlaylistKeyboard.removeSelectedTracks()
                return nil
            default:
                return event
            }
        }

        if option, !command, !control, !shift {
            switch key {
            case 126:
                WinampPlaylistKeyboard.moveSelectedTracks(by: -1)
                return nil
            case 125:
                WinampPlaylistKeyboard.moveSelectedTracks(by: 1)
                return nil
            default:
                return event
            }
        }

        if command, !option, !control {
            switch key {
            case 0 where !shift:
                WinampPlaylistKeyboard.selectAll()
                return nil
            case 34 where !shift:
                WinampPlaylistKeyboard.invertSelection()
                return nil
            case 51, 117:
                if shift {
                    playlistManager?.clearPlaylist()
                    WinampPlaylistKeyboard.clearSelection()
                } else {
                    WinampPlaylistKeyboard.cropToSelection()
                }
                return nil
            case 15:
                if shift {
                    playlistManager?.randomizeTracks()
                } else {
                    playlistManager?.reverseTracks()
                }
                return nil
            case 18 where shift:
                playlistManager?.sortTracks(by: .title)
                return nil
            case 19 where shift:
                playlistManager?.sortTracks(by: .fileName)
                return nil
            case 20 where shift:
                playlistManager?.sortTracks(by: .path)
                return nil
            default:
                return event
            }
        }

        return event
    }

    private static func seek(_ player: AudioPlayer?, by delta: TimeInterval) {
        guard let player else { return }
        player.seek(to: player.currentTime + delta)
    }

    private static func adjustVolume(_ player: AudioPlayer?, by delta: Float) {
        guard let player else { return }
        player.setVolume(player.volume + delta)
    }
}
