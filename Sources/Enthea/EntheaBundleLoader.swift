import Foundation

/// Resolves the vendored ENTHEA bundle from `Bundle.main`.
///
/// `Resources/Enthea` must be a **folder reference** in `project.pbxproj` so
/// `Contents/Resources/Enthea/` exists at runtime. Loose file refs flatten into
/// `Contents/Resources/` and both lookups return `nil`.
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
