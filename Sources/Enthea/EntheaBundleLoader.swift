import Foundation

/// Resolves the vendored ENTHEA bundle from `Bundle.main`.
///
/// Stage 1 stub: `Resources/Enthea/` does not exist yet, so this always returns `nil` and
/// `EntheaWKHostView` falls back to its inline placeholder HTML. Task 2 adds the real
/// folder reference; deliberately no fallback chain here once it does, since a
/// nil-returning fallback would hide exactly the "flattened into Contents/Resources"
/// bundling mistake this loader exists to catch.
enum EntheaBundleLoader {
    static func directoryURL(in bundle: Bundle = .main) -> URL? {
        guard let url = bundle.url(forResource: "Enthea", withExtension: nil),
              (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        else { return nil }
        return url
    }

    static func indexHTMLURL(in bundle: Bundle = .main) -> URL? {
        guard let directory = directoryURL(in: bundle) else { return nil }
        let index = directory.appendingPathComponent("index.html")
        return FileManager.default.fileExists(atPath: index.path) ? index : nil
    }
}
