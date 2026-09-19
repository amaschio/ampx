@testable import AmpX
import AppKit
import XCTest

@MainActor
final class AmpXCompactKeyboardTests: XCTestCase {
    func testCollapsedPlaylistRetainsModuleIdentityWithoutEditingRows() {
        let context = AmpXFocusContext(module: .playlist, control: nil, playlistEditingEnabled: false)
        for code: UInt16 in [126, 125, 36, 51, 117] {
            XCTAssertEqual(AmpXKeyRouter.route(event: self.key(code), context: context), .unhandled)
        }
        XCTAssertEqual(context.module, .playlist)
        XCTAssertEqual(AmpXKeyRouter.route(event: self.key(49), context: context), .global)
    }

    func testCompactTimerAndSpectrumHandleReturnWhileSpaceRemainsGlobal() {
        let state = AmpXPlayerPresentationState()
        let timer = TimeDisplayView(skin: ClassicModernSkin(), presentationState: state)
        timer.style = .compact
        let spectrum = SpectrumWellView(skin: ClassicModernSkin())
        spectrum.geometry = .compact
        let body = AmpXModuleContent(skin: ClassicModernSkin())
        body.addSubview(timer)
        body.addSubview(spectrum)
        let module = AmpXModuleView(moduleID: .player, content: body, skin: ClassicModernSkin())
        let window = AmpXHostWindow(contentRect: CGRect(x: 100, y: 100, width: 490, height: 290),
                                    styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = module
        defer { window.close() }
        for view in [timer as NSView, spectrum] {
            XCTAssertTrue(window.makeFirstResponder(view))
            let context = AmpXKeyRouter.focusContext(from: window)
            XCTAssertEqual(context.control, .button)
            XCTAssertEqual(context.module, .player)
            XCTAssertEqual(AmpXKeyRouter.route(event: self.key(49), context: context), .global)
            XCTAssertTrue(AmpXKeyRouter.dispatch(self.key(36), context: context, window: window,
                                                audioPlayer: nil, playlistManager: nil, entheaTheater: nil))
        }
        XCTAssertTrue(state.showRemainingTime)
        XCTAssertEqual(spectrum.settings.style, .smoothSpectrum)
    }

    func testSpaceDoesNotActivateCompactStopOrExpand() {
        for code: UInt16 in [49, 36, 76] {
            XCTAssertEqual(AmpXKeyRouter.route(event: self.key(code), context: .init(module: .player, control: .button)),
                           code == 49 ? .global : .control)
        }
    }

    private func key(_ code: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                        context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code)!
    }
}
