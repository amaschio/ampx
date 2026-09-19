import AppKit
import Foundation

enum AmpXControlFocus: Equatable {
    case button
    case slider
}

struct AmpXFocusContext: Equatable {
    var module: AmpXModuleID?
    var control: AmpXControlFocus?
    var textResponderActive = false
}

enum AmpXKeyRoute: Equatable {
    case control
    case playlist
    case enthea
    case global
    case unhandled
}

enum AmpXModuleCommand: Equatable {
    case moveUp
    case moveDown
    case toggleDetach
    case toggleCollapse
}

@MainActor
enum AmpXKeyRouter {
    private static let seekStep: TimeInterval = 5
    private static let volumeStep: Float = 0.05

    static func route(event: NSEvent, context: AmpXFocusContext) -> AmpXKeyRoute {
        if self.moduleCommand(for: event) != nil {
            return .unhandled
        }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let key = event.keyCode

        if let control = context.control, matchesControlKey(key, control: control) {
            return .control
        }

        if context.module == .playlist, self.matchesPlaylistKey(event, flags: flags) {
            return .playlist
        }

        if context.module == .enthea, self.matchesEntheaKey(event, flags: flags) {
            return .enthea
        }

        if context.textResponderActive, self.isTypingGlobalKey(key, flags: flags) {
            return .unhandled
        }
        if self.matchesGlobalKey(event, flags: flags, playlistFocused: context.module == .playlist) {
            return .global
        }

        return .unhandled
    }

    static func moduleCommand(for event: NSEvent) -> AmpXModuleCommand? {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard flags == [.command, .option] else { return nil }

        switch event.keyCode {
        case 126:
            return .moveUp
        case 125:
            return .moveDown
        case 2:
            return .toggleDetach
        case 8:
            return .toggleCollapse
        default:
            return nil
        }
    }

    @discardableResult
    static func dispatch(
        _ event: NSEvent,
        context: AmpXFocusContext,
        controlHandler: () -> Void,
        playlistHandler: () -> Void,
        entheaHandler: () -> Void,
        globalHandler: () -> Void
    ) -> Bool {
        switch self.route(event: event, context: context) {
        case .control:
            controlHandler()
            return true
        case .playlist:
            playlistHandler()
            return true
        case .enthea:
            entheaHandler()
            return true
        case .global:
            globalHandler()
            return true
        case .unhandled:
            return false
        }
    }

    @discardableResult
    static func dispatch(
        _ event: NSEvent,
        context: AmpXFocusContext,
        window: NSWindow?,
        audioPlayer: AudioPlayer?,
        playlistManager: PlaylistManager?,
        entheaTheater: AmpXEntheaTheaterHandling?
    ) -> Bool {
        switch self.route(event: event, context: context) {
        case .control:
            self.dispatchControl(event, window: window)
        case .playlist:
            self.dispatchPlaylist(event, playlistManager: playlistManager)
        case .enthea:
            self.dispatchEnthea(event, entheaTheater: entheaTheater)
        case .global:
            self.dispatchGlobal(
                event,
                audioPlayer: audioPlayer,
                playlistManager: playlistManager,
                playlistFocused: context.module == .playlist
            )
        case .unhandled:
            false
        }
    }

    static func focusContext(from window: NSWindow?) -> AmpXFocusContext {
        guard let window else { return AmpXFocusContext() }

        let textResponderActive = self.isTextResponder(window.firstResponder)

        guard let responder = window.firstResponder as? NSView else {
            return AmpXFocusContext(textResponderActive: textResponderActive)
        }

        var module: AmpXModuleID?
        var control: AmpXControlFocus?

        var view: NSView? = responder
        while let current = view {
            if control == nil {
                if current is AmpXButton {
                    control = .button
                } else if current is AmpXSlider {
                    control = .slider
                }
            }

            if let moduleView = current as? AmpXModuleView {
                module = moduleView.moduleID
                break
            }
            if let header = current as? AmpXModuleHeaderView {
                module = header.moduleID
                break
            }
            view = current.superview
        }

        return AmpXFocusContext(
            module: module,
            control: control,
            textResponderActive: textResponderActive
        )
    }

    @discardableResult
    static func handle(
        _ event: NSEvent,
        window: NSWindow?,
        audioPlayer: AudioPlayer?,
        playlistManager: PlaylistManager?,
        entheaTheater: AmpXEntheaTheaterHandling?,
        moduleCommandHandler: ((AmpXModuleCommand) -> Void)?
    ) -> NSEvent? {
        guard let window, window.isKeyWindow else { return event }

        if let entheaTheater, entheaTheater.isInTheater {
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if flags.isEmpty, event.keyCode == 53 {
                entheaTheater.exitTheater()
                return nil
            }
        }

        if let command = moduleCommand(for: event) {
            moduleCommandHandler?(command)
            return nil
        }

        let context = self.focusContext(from: window)
        let handled = self.dispatch(
            event,
            context: context,
            window: window,
            audioPlayer: audioPlayer,
            playlistManager: playlistManager,
            entheaTheater: entheaTheater
        )
        return handled ? nil : event
    }

    private static func matchesControlKey(_ key: UInt16, control: AmpXControlFocus) -> Bool {
        switch control {
        case .button:
            key == 36 || key == 76 || key == 53
        case .slider:
            key == 123 || key == 124 || key == 125 || key == 126 || key == 53
        }
    }

    private static func matchesPlaylistKey(_ event: NSEvent, flags: NSEvent.ModifierFlags) -> Bool {
        let key = event.keyCode
        let shift = flags.contains(.shift)
        let command = flags.contains(.command)
        let option = flags.contains(.option)
        let control = flags.contains(.control)

        if control, !command {
            return false
        }

        if !command, !option, !control {
            switch key {
            case 126, 125, 115, 119, 116, 121, 36, 51, 117:
                return true
            default:
                return false
            }
        }

        if option, !command, !control, !shift {
            return key == 126 || key == 125
        }

        if command, !option, !control {
            switch key {
            case 0, 34, 51, 117, 15, 18, 19, 20:
                return true
            default:
                return false
            }
        }

        return false
    }

    private static func matchesEntheaKey(_ event: NSEvent, flags: NSEvent.ModifierFlags) -> Bool {
        guard flags.isEmpty else { return false }
        return event.keyCode == 3 || event.keyCode == 53
    }

    private static func matchesGlobalKey(
        _ event: NSEvent,
        flags: NSEvent.ModifierFlags,
        playlistFocused: Bool
    ) -> Bool {
        let noMods = flags.isEmpty
        let key = event.keyCode

        if noMods, key == 49 {
            return true
        }

        if noMods {
            switch key {
            case 8, 15, 1, 7, 9, 6, 11, 37:
                return true
            default:
                break
            }
        }

        if flags == [.shift], key == 37 {
            return true
        }

        if noMods, !playlistFocused {
            switch key {
            case 123, 124, 126, 125:
                return true
            default:
                break
            }
        }

        return false
    }

    /// Unmodified global keys that a focused text field needs as typed characters.
    private static func isTypingGlobalKey(_ key: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        guard flags.isEmpty else { return false }
        switch key {
        case 49, 8, 15, 1, 7, 9, 6, 11, 37:
            return true
        default:
            return false
        }
    }

    private static func isTextResponder(_ responder: NSResponder?) -> Bool {
        responder is NSTextView || responder is NSTextField
    }

    @discardableResult
    private static func dispatchControl(_ event: NSEvent, window: NSWindow?) -> Bool {
        guard let responder = window?.firstResponder else { return false }

        switch event.keyCode {
        case 36, 76:
            if let button = responder as? AmpXButton {
                return button.performKeyboardPress()
            }
        case 123, 124, 125, 126:
            if let slider = responder as? AmpXSlider {
                return slider.handleArrowKey(event)
            }
        case 53:
            window?.makeFirstResponder(nil)
            return true
        default:
            break
        }

        return false
    }

    @discardableResult
    private static func dispatchPlaylist(
        _ event: NSEvent,
        playlistManager: PlaylistManager?
    ) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let key = event.keyCode
        let shift = flags.contains(.shift)
        let command = flags.contains(.command)
        let option = flags.contains(.option)
        let control = flags.contains(.control)

        if control, !command {
            return false
        }

        if !command, !option, !control {
            switch key {
            case 126:
                AmpXPlaylistKeyboard.moveSelection(by: -1, extend: shift)
                return true
            case 125:
                AmpXPlaylistKeyboard.moveSelection(by: 1, extend: shift)
                return true
            case 115:
                AmpXPlaylistKeyboard.jumpToStart(extend: shift)
                return true
            case 119:
                AmpXPlaylistKeyboard.jumpToEnd(extend: shift)
                return true
            case 116:
                AmpXPlaylistKeyboard.pageSelection(direction: -1, extend: shift)
                return true
            case 121:
                AmpXPlaylistKeyboard.pageSelection(direction: 1, extend: shift)
                return true
            case 36:
                AmpXPlaylistKeyboard.playSelectedTrack()
                return true
            case 51, 117:
                AmpXPlaylistKeyboard.removeSelectedTracks()
                return true
            default:
                return false
            }
        }

        if option, !command, !control, !shift {
            switch key {
            case 126:
                AmpXPlaylistKeyboard.moveSelectedTracks(by: -1)
                return true
            case 125:
                AmpXPlaylistKeyboard.moveSelectedTracks(by: 1)
                return true
            default:
                return false
            }
        }

        if command, !option, !control {
            switch key {
            case 0 where !shift:
                AmpXPlaylistKeyboard.selectAll()
                return true
            case 34 where !shift:
                AmpXPlaylistKeyboard.invertSelection()
                return true
            case 51, 117:
                if shift {
                    playlistManager?.clearPlaylist()
                    AmpXPlaylistKeyboard.clearSelection()
                } else {
                    AmpXPlaylistKeyboard.cropToSelection()
                }
                return true
            case 15:
                if shift {
                    playlistManager?.randomizeTracks()
                } else {
                    playlistManager?.reverseTracks()
                }
                return true
            case 18 where shift:
                playlistManager?.sortTracks(by: .title)
                return true
            case 19 where shift:
                playlistManager?.sortTracks(by: .fileName)
                return true
            case 20 where shift:
                playlistManager?.sortTracks(by: .path)
                return true
            default:
                return false
            }
        }

        return false
    }

    @discardableResult
    private static func dispatchEnthea(
        _ event: NSEvent,
        entheaTheater: AmpXEntheaTheaterHandling?
    ) -> Bool {
        switch event.keyCode {
        case 3:
            entheaTheater?.toggleTheater()
            return true
        case 53:
            if entheaTheater?.isInTheater == true {
                entheaTheater?.exitTheater()
                return true
            }
            return false
        default:
            return false
        }
    }

    @discardableResult
    private static func dispatchGlobal(
        _ event: NSEvent,
        audioPlayer: AudioPlayer?,
        playlistManager: PlaylistManager?,
        playlistFocused: Bool
    ) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let noMods = flags.isEmpty
        let key = event.keyCode

        if noMods, key == 49 {
            audioPlayer?.togglePlayPause()
            return true
        }

        if noMods {
            switch key {
            case 8, 7:
                audioPlayer?.togglePlayPause()
                return true
            case 15:
                playlistManager?.repeatEnabled.toggle()
                return true
            case 1:
                playlistManager?.shuffleEnabled.toggle()
                return true
            case 9:
                audioPlayer?.stop()
                return true
            case 6:
                playlistManager?.previous()
                return true
            case 11:
                playlistManager?.next()
                return true
            case 37:
                playlistManager?.showFilePicker()
                return true
            default:
                break
            }
        }

        if flags == [.shift], key == 37 {
            playlistManager?.showFolderPicker()
            return true
        }

        if noMods, !playlistFocused {
            switch key {
            case 123:
                self.seek(audioPlayer, by: -self.seekStep)
                return true
            case 124:
                self.seek(audioPlayer, by: self.seekStep)
                return true
            case 126:
                self.adjustVolume(audioPlayer, by: self.volumeStep)
                return true
            case 125:
                self.adjustVolume(audioPlayer, by: -self.volumeStep)
                return true
            default:
                break
            }
        }

        return false
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

@MainActor
protocol AmpXEntheaTheaterHandling: AnyObject {
    var isInTheater: Bool { get }
    func toggleTheater()
    func exitTheater()
}
