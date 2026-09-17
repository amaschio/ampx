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
        // Use the async API so WebKit does not invoke a @MainActor completion from C++
        // (macOS 26 Swift 6 executor check SIGSEGV).
        let script = javaScriptString
        let webView = self.webView
        Task { @MainActor in
            do {
                let result = try await webView.evaluateJavaScript(script)
                completionHandler?(result, nil)
            } catch {
                completionHandler?(nil, error)
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
    /// Host-chosen push ceiling (30 docked-small / 60 large). Rate-limited inside `tick`.
    var maxPushHz: Double = 60

    private let featureBus: AudioFeatureBus
    private let lock = NSLock()
    private weak var evaluator: EntheaJavaScriptEvaluating?
    private var pushInFlight = false
    private var lastPushTime: CFAbsoluteTime = 0

    init(featureBus: AudioFeatureBus = .shared, evaluator: EntheaJavaScriptEvaluating?) {
        self.featureBus = featureBus
        self.evaluator = evaluator
    }

    func attach(evaluator: EntheaJavaScriptEvaluating?) {
        self.lock.lock()
        self.evaluator = evaluator
        self.lock.unlock()
    }

    /// Call from a display timer while the Enthea body is visible and not minimized.
    /// Skips when inactive, in-flight, rate-limited, or playback is stopped (Task 7 idle policy).
    func tick() {
        self.lock.lock()
        let active = self.isActive
        let inFlight = self.pushInFlight
        let evaluator = self.evaluator
        let maxHz = max(1, self.maxPushHz)
        let now = CFAbsoluteTimeGetCurrent()
        let due = (now - self.lastPushTime) >= (1.0 / maxHz)
        guard active, !inFlight, due, let evaluator else {
            self.lock.unlock()
            return
        }
        self.lock.unlock()

        let raw = self.featureBus.rawBinSnapshot()
        // Stop IPC when idle — render loop is paused separately via setRenderPaused.
        guard raw.isPlaying else { return }

        self.lock.lock()
        self.pushInFlight = true
        self.lastPushTime = now
        self.lock.unlock()

        let wave = self.featureBus.waveformRing.readResampled(count: EntheaAudioPayloadCodec.waveCount)
        let blob = EntheaAudioPayloadCodec.encode(bins: raw.bins, left: wave.left, right: wave.right)
        let js = "window.winampAudio&&window.winampAudio.push('\(blob)',\(raw.sampleRate),true);"

        evaluator.evaluateJavaScript(js) { [weak self] _, _ in
            guard let self else { return }
            self.lock.lock()
            self.pushInFlight = false
            self.lock.unlock()
        }
    }
}
