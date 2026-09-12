import Foundation

@MainActor
protocol AmpXEntheaHosting: AnyObject {
    func setAudioBridgeActive(_ active: Bool)
    func teardown()
}

extension EntheaWKHostView: AmpXEntheaHosting {}

@MainActor
final class EntheaHostLifecycle {
    private(set) var host: (any AmpXEntheaHosting)?
    private var isVisible = false

    init(host: any AmpXEntheaHosting) {
        self.host = host
    }

    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        host?.setAudioBridgeActive(visible)
    }

    func close() {
        host?.teardown()
        host = nil
        isVisible = false
    }
}
