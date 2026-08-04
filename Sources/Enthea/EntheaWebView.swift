import AppKit
import SwiftUI
import WebKit

/// Panel body mode for the Visualizer: `.metal` renders the existing MilkDrop `MTKView`,
/// `.enthea` renders the `WKWebView` host. Default is `.enthea` (Task 2+); Metal stays
/// on the migration strip until Stage 5 retires it.
enum EntheaBodyMode: String {
    case metal
    case enthea
}

/// Hosts a `WKWebView` that always fills its AppKit bounds, mirroring `MilkdropMTKHostView`.
/// Needed because panel `NSHostingController`s use `sizingOptions = []`, which often leaves
/// a bare web view at 0×0 inside SwiftUI layout.
final class EntheaWKHostView: NSView, WKNavigationDelegate {
    let webView: WKWebView
    private let jsEvaluator: EntheaWKJavaScriptEvaluator
    private let audioBridge: EntheaAudioBridge
    private var pushTimer: Timer?
    private var didLoadEnthea = false
    /// Classic strip / prefs owner — attached from SwiftUI representable.
    weak var panelController: EntheaPanelController?

    override init(frame frameRect: NSRect) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.suppressesIncrementalRendering = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView = webView
        let jsEvaluator = EntheaWKJavaScriptEvaluator(webView: webView)
        self.jsEvaluator = jsEvaluator
        self.audioBridge = EntheaAudioBridge(featureBus: .shared, evaluator: jsEvaluator)
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
        self.audioBridge.isActive = active
        if active {
            self.startPushTimerIfNeeded()
        } else {
            self.stopPushTimer()
        }
    }

    /// Blanking the page does NOT stop the WebContent process — only releasing the
    /// `WKWebView` does. `WinampPanelWindowManager.hidePanel` nils `contentViewController`
    /// for `.visualizer`, which deallocates this view; this just stops work in the window
    /// between that and dealloc.
    func teardown() {
        self.setAudioBridgeActive(false)
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
        guard self.didLoadEnthea, let controller = self.panelController else { return }
        let evaluator = self.jsEvaluator
        Task { @MainActor in
            controller.attach(evaluator: evaluator)
            controller.hostDidFinishLoad()
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
    @ObservedObject var controller: EntheaPanelController

    func makeNSView(context: Context) -> EntheaWKHostView {
        let host = EntheaWKHostView(frame: CGRect(origin: .zero, size: self.size))
        host.panelController = self.controller
        if self.isActive {
            host.loadEnthea()
            host.setAudioBridgeActive(true)
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
        } else {
            host.teardown()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView _: EntheaWKHostView, context _: Context) -> CGSize? {
        self.size
    }
}
