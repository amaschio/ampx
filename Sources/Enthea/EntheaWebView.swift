import AppKit
import SwiftUI
import WebKit

/// Panel body mode for the Visualizer: `.metal` renders the existing MilkDrop `MTKView`,
/// `.enthea` renders the `WKWebView` host. Defaults to `.metal` until Stage 3 lands live
/// audio — an empty/placeholder ENTHEA host must never be the thing users see by default.
enum EntheaBodyMode: String {
    case metal
    case enthea
}

/// Hosts a `WKWebView` that always fills its AppKit bounds, mirroring `MilkdropMTKHostView`.
/// Needed because panel `NSHostingController`s use `sizingOptions = []`, which often leaves
/// a bare web view at 0×0 inside SwiftUI layout.
final class EntheaWKHostView: NSView {
    let webView: WKWebView

    override init(frame frameRect: NSRect) {
        // A configuration is required for WKUserScript injection and message handlers in
        // later tasks. nonPersistent(): ENTHEA's localStorage writes (scene snapshots, MIDI
        // map) are all try/catch-guarded, so discarding them is harmless.
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.suppressesIncrementalRendering = true
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor
        self.webView.underPageBackgroundColor = .black
        self.addSubview(self.webView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        self.webView.frame = self.bounds
    }

    func loadPlaceholder() {
        let html = "<!doctype html><meta charset=utf-8><body style='margin:0;background:#000;color:#0f0;font:12px monospace'>ENTHEA host</body>"
        self.webView.loadHTMLString(html, baseURL: nil)
    }

    /// Blanking the page does NOT stop the WebContent process — only releasing the
    /// `WKWebView` does. `WinampPanelWindowManager.hidePanel` nils `contentViewController`
    /// for `.visualizer`, which deallocates this view; this just stops work in the window
    /// between that and dealloc.
    func teardown() {
        self.webView.stopLoading()
        self.webView.load(URLRequest(url: URL(string: "about:blank")!))
    }
}

struct EntheaWebView: NSViewRepresentable {
    var isActive: Bool
    var size: CGSize

    func makeNSView(context: Context) -> EntheaWKHostView {
        let host = EntheaWKHostView(frame: CGRect(origin: .zero, size: self.size))
        if self.isActive { host.loadPlaceholder() }
        return host
    }

    func updateNSView(_ host: EntheaWKHostView, context: Context) {
        host.frame.size = self.size
        if self.isActive {
            if host.webView.url == nil { host.loadPlaceholder() }
        } else {
            host.teardown()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView _: EntheaWKHostView, context _: Context) -> CGSize? {
        self.size
    }
}
