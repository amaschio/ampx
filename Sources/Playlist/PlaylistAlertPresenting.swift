import AppKit

/// Presents playlist file-action errors to the user. Injected so unit tests never call `NSAlert.runModal`.
@MainActor
protocol PlaylistAlertPresenting: AnyObject {
    func presentError(title: String, message: String)
}

@MainActor
final class AppKitPlaylistAlertPresenter: PlaylistAlertPresenting {
    func presentError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

/// No-op presenter for unit tests and headless runs.
@MainActor
final class SilentPlaylistAlertPresenter: PlaylistAlertPresenting {
    func presentError(title _: String, message _: String) {}
}
