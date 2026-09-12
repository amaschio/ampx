import AppKit
import SwiftUI
import WebKit

/// Hosts a `WKWebView` that always fills its AppKit bounds, mirroring `MilkdropMTKHostView`.
/// Needed because panel `NSHostingController`s use `sizingOptions = []`, which often leaves
/// a bare web view at 0×0 inside SwiftUI layout.
final class EntheaWKHostView: NSView, WKNavigationDelegate {
    let webView: WKWebView
    private let jsEvaluator: EntheaWKJavaScriptEvaluator
    private let audioBridge: EntheaAudioBridge
    private let trackBridge: EntheaTrackBridge
    private var pushTimer: Timer?
    private var didLoadEnthea = false
    /// Classic strip / prefs owner — attached from SwiftUI representable.
    weak var panelController: EntheaPanelController?
    private var lastTrackURL: URL?
    private var lastArtworkTrackURL: URL?
    private var artworkTask: Task<Void, Never>?
    private var lastRenderPaused: Bool?
    private var occlusionObserver: NSObjectProtocol?
    private var isPlaying = false
    private var isTheater = false
    /// Panel wants audio/timeline IPC; actual `audioBridge.isActive` also requires visible window.
    private var wantsAudioBridge = false

    override init(frame frameRect: NSRect) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.suppressesIncrementalRendering = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView = webView
        let jsEvaluator = EntheaWKJavaScriptEvaluator(webView: webView)
        self.jsEvaluator = jsEvaluator
        self.audioBridge = EntheaAudioBridge(featureBus: .shared, evaluator: jsEvaluator)
        self.trackBridge = EntheaTrackBridge(evaluator: jsEvaluator)
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor
        self.webView.underPageBackgroundColor = .black
        self.webView.navigationDelegate = self
        self.addSubview(self.webView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        self.webView.frame = self.bounds
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.clearOcclusionObserver()
        guard let window else {
            self.artworkTask?.cancel()
            return
        }
        self.occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.applyRenderAndPushPolicy()
        }
        self.applyRenderAndPushPolicy()
    }

    private func clearOcclusionObserver() {
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
            self.occlusionObserver = nil
        }
    }

    /// Load vendored ENTHEA from the folder-reference bundle, or a tiny placeholder if missing.
    func loadEnthea() {
        if let index = EntheaBundleLoader.indexHTMLURL(),
           let directory = EntheaBundleLoader.directoryURL()
        {
            self.didLoadEnthea = true
            self.webView.loadFileURL(index, allowingReadAccessTo: directory)
            return
        }
        self.didLoadEnthea = false
        self.loadPlaceholder()
    }

    func loadPlaceholder() {
        let html = """
        <!doctype html><meta charset=utf-8>
        <body style="margin:0;background:#000;color:#0f0;font:12px monospace;display:flex;align-items:center;justify-content:center;height:100vh">
        ENTHEA
        </body>
        """
        self.webView.loadHTMLString(html, baseURL: nil)
    }

    func applyBackingScale(for size: CGSize) {
        let screenScale = self.window?.screen?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        let scale = EntheaBackingScale.scale(forSize: size, screenScale: screenScale)
        let js = "window.winampEnthea && window.winampEnthea.setBackingScale(\(scale));"
        self.webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func setAudioBridgeActive(_ active: Bool) {
        self.wantsAudioBridge = active
        self.applyRenderAndPushPolicy()
    }

    /// Push playlist playhead + kick analysis / cover art when the current track URL changes.
    func updatePlayback(trackURL: URL?, seconds: TimeInterval, isPlaying: Bool, isTheater: Bool) {
        self.isPlaying = isPlaying
        self.isTheater = isTheater
        if trackURL != self.lastTrackURL {
            self.lastTrackURL = trackURL
            self.trackBridge.trackDidChange(url: trackURL)
            self.loadCoverArt(for: trackURL)
        }
        self.trackBridge.tickPosition(seconds: seconds, paused: !isPlaying)
        self.applyRenderAndPushPolicy()
    }

    /// Blanking the page does NOT stop the WebContent process — only releasing the
    /// `WKWebView` does. Detaching or closing the ENTHEA module host nils `contentViewController`
    /// for `.visualizer`, which deallocates this view; this just stops work in the window
    /// between that and dealloc.
    func teardown() {
        self.clearOcclusionObserver()
        self.setAudioBridgeActive(false)
        self.trackBridge.clearTimeline()
        self.lastTrackURL = nil
        self.lastArtworkTrackURL = nil
        self.artworkTask?.cancel()
        self.artworkTask = nil
        self.lastRenderPaused = nil
        let controller = self.panelController
        Task { @MainActor in
            controller?.hostDidTeardown()
        }
        self.didLoadEnthea = false
        self.webView.stopLoading()
        self.webView.load(URLRequest(url: URL(string: "about:blank")!))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.applyBackingScale(for: self.bounds.size)
        webView.evaluateJavaScript(
            "window.winampEnthea && window.winampEnthea.hideChrome();",
            completionHandler: nil
        )
        self.applyRenderAndPushPolicy()
        // Re-push cover art after a reload so Image Warp survives WebContent restarts.
        if let url = self.lastTrackURL {
            self.lastArtworkTrackURL = nil
            self.loadCoverArt(for: url)
        }
        guard self.didLoadEnthea, let controller = self.panelController else { return }
        let evaluator = self.jsEvaluator
        Task { @MainActor in
            controller.attach(evaluator: evaluator)
            controller.hostDidFinishLoad()
        }
        self.trackBridge.hostDidBecomeReady()
    }

    private func applyRenderAndPushPolicy() {
        let size = self.bounds.size
        self.audioBridge.maxPushHz = EntheaPushRatePolicy.pushHz(
            forContentSize: size,
            isTheater: self.isTheater
        )

        let occluded: Bool
        if let window {
            occluded = !window.occlusionState.contains(.visible)
        } else {
            occluded = true
        }

        let audioOn = self.wantsAudioBridge && !occluded
        self.audioBridge.isActive = audioOn
        self.trackBridge.isActive = audioOn
        if audioOn {
            self.startPushTimerIfNeeded()
        } else {
            self.stopPushTimer()
        }

        let paused = !self.wantsAudioBridge || !self.isPlaying || occluded
        guard self.lastRenderPaused != paused else { return }
        self.lastRenderPaused = paused
        let js = "window.winampEnthea&&window.winampEnthea.setRenderPaused(\(paused ? "true" : "false"));"
        self.webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func loadCoverArt(for trackURL: URL?) {
        self.artworkTask?.cancel()
        guard let trackURL else {
            self.lastArtworkTrackURL = nil
            return
        }
        guard trackURL != self.lastArtworkTrackURL else { return }
        self.artworkTask = Task { [weak self] in
            let data = await TrackArtworkLoader.loadImageData(from: trackURL)
            guard !Task.isCancelled, let self, let data else { return }
            let dataURL = "data:image/jpeg;base64,\(data.base64EncodedString())"
            guard let encoded = try? String(
                data: JSONSerialization.data(withJSONObject: dataURL),
                encoding: .utf8
            ) else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.lastArtworkTrackURL = trackURL
                let js = "window.winampEnthea&&window.winampEnthea.setCoverArt(\(encoded));"
                self.webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }

    private func startPushTimerIfNeeded() {
        guard self.pushTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.audioBridge.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pushTimer = timer
    }

    private func stopPushTimer() {
        self.pushTimer?.invalidate()
        self.pushTimer = nil
    }
}

struct EntheaWebView: NSViewRepresentable {
    var isActive: Bool
    var size: CGSize
    var isTheater: Bool
    var trackURL: URL?
    var currentTime: TimeInterval
    var isPlaying: Bool
    @ObservedObject var controller: EntheaPanelController

    func makeNSView(context: Context) -> EntheaWKHostView {
        let host = EntheaWKHostView(frame: CGRect(origin: .zero, size: self.size))
        host.panelController = self.controller
        if self.isActive {
            host.loadEnthea()
            host.setAudioBridgeActive(true)
            host.updatePlayback(
                trackURL: self.trackURL,
                seconds: self.currentTime,
                isPlaying: self.isPlaying,
                isTheater: self.isTheater
            )
        }
        return host
    }

    func updateNSView(_ host: EntheaWKHostView, context: Context) {
        host.panelController = self.controller
        host.frame.size = self.size
        if self.isActive {
            let url = host.webView.url
            let needsLoad = url == nil
                || url?.absoluteString == "about:blank"
                || !(url?.isFileURL ?? false)
            if needsLoad {
                host.loadEnthea()
            } else {
                host.applyBackingScale(for: self.size)
            }
            host.setAudioBridgeActive(true)
            host.updatePlayback(
                trackURL: self.trackURL,
                seconds: self.currentTime,
                isPlaying: self.isPlaying,
                isTheater: self.isTheater
            )
        } else {
            host.teardown()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView _: EntheaWKHostView, context _: Context) -> CGSize? {
        self.size
    }
}
