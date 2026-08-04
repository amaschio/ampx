import Foundation
import WebKit

/// Thin seam so `EntheaAudioBridge` can be unit-tested without a `WKWebView`.
protocol EntheaJavaScriptEvaluating: AnyObject {
    func evaluateJavaScript(
        _ javaScriptString: String,
        completionHandler: (@Sendable (Any?, (any Error)?) -> Void)?
    )
}

/// Adapts `WKWebView.evaluateJavaScript` onto the bridge protocol.
final class EntheaWKJavaScriptEvaluator: EntheaJavaScriptEvaluating, @unchecked Sendable {
    private let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
    }

    func evaluateJavaScript(
        _ javaScriptString: String,
        completionHandler: (@Sendable (Any?, (any Error)?) -> Void)?
    ) {
        // WKWebView is MainActor-isolated; hop there, then call the Sendable completion.
        let script = javaScriptString
        let webView = self.webView
        Task { @MainActor in
            webView.evaluateJavaScript(script) { result, error in
                completionHandler?(result, error)
            }
        }
    }
}

/// Pushes raw FFT bins + stereo PCM into ENTHEA's fake AnalyserNode via `winampAudio.push`.
///
/// Coalesces: at most one `evaluateJavaScript` in flight. Inactive/minimized hosts must
/// set `isActive = false` so ticks no-op (no unbounded IPC queue when WebContent stalls).
final class EntheaAudioBridge: @unchecked Sendable {
    var isActive = false

    private let featureBus: AudioFeatureBus
    private let lock = NSLock()
    private weak var evaluator: EntheaJavaScriptEvaluating?
    private var pushInFlight = false

    init(featureBus: AudioFeatureBus = .shared, evaluator: EntheaJavaScriptEvaluating?) {
        self.featureBus = featureBus
        self.evaluator = evaluator
    }

    func attach(evaluator: EntheaJavaScriptEvaluating?) {
        self.lock.lock()
        self.evaluator = evaluator
        self.lock.unlock()
    }

    /// Call from a ~60 Hz display timer while the Enthea body is visible and not minimized.
    func tick() {
        self.lock.lock()
        let active = self.isActive
        let inFlight = self.pushInFlight
        let evaluator = self.evaluator
        guard active, !inFlight, let evaluator else {
            self.lock.unlock()
            return
        }
        self.pushInFlight = true
        self.lock.unlock()

        let raw = self.featureBus.rawBinSnapshot()
        let wave = self.featureBus.waveformRing.readResampled(count: EntheaAudioPayloadCodec.waveCount)
        let blob = EntheaAudioPayloadCodec.encode(bins: raw.bins, left: wave.left, right: wave.right)
        let js = "window.winampAudio&&window.winampAudio.push('\(blob)',\(raw.sampleRate),\(raw.isPlaying ? "true" : "false"));"

        evaluator.evaluateJavaScript(js) { [weak self] _, _ in
            guard let self else { return }
            self.lock.lock()
            self.pushInFlight = false
            self.lock.unlock()
        }
    }
}
