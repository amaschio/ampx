import AppKit
import CoreText
import os

enum AmpXFonts {
    private static let logger = Logger(subsystem: "com.ampx.macos", category: "AmpXFonts")
    nonisolated(unsafe) private static var didRegister = false
    nonisolated(unsafe) private static var loggedUnavailableFaces: Set<String> = []
    nonisolated(unsafe) private static var postScriptNames: [NSFont.Weight: String] = [:]

    private static let bundledResources = [
        "RobotoMono-Regular",
        "RobotoMono-Medium",
        "RobotoMono-SemiBold",
    ]

    static func register(bundle: Bundle = .main) {
        guard !didRegister else { return }
        didRegister = true

        for resource in bundledResources {
            guard let url = bundle.url(forResource: resource, withExtension: "ttf", subdirectory: "Fonts")
                ?? bundle.url(forResource: resource, withExtension: "ttf")
            else {
                logger.error("Missing bundled font resource \(resource, privacy: .public).ttf")
                continue
            }
            registerFont(at: url)
        }

        postScriptNames = [
            .regular: facePostScriptName(for: "RobotoMono-Regular.ttf", bundle: bundle) ?? "RobotoMono-Regular",
            .medium: facePostScriptName(for: "RobotoMono-Medium.ttf", bundle: bundle) ?? "RobotoMono-Medium",
            .semibold: facePostScriptName(for: "RobotoMono-SemiBold.ttf", bundle: bundle) ?? "RobotoMono-SemiBold",
        ]
    }

    static func font(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        register()
        let postScriptName = postScriptNames[resolvedWeight(weight)] ?? "RobotoMono-Regular"
        return resolve(name: postScriptName, size: size, weight: weight, lookup: NSFont.init(name:size:))
    }

    static func resolve(
        name: String,
        size: CGFloat,
        weight: NSFont.Weight,
        lookup: (String, CGFloat) -> NSFont?
    ) -> NSFont {
        if let font = lookup(name, size) {
            return font
        }
        logUnavailableFace(name)
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    private static func registerFont(at url: URL) {
        var registrationError: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &registrationError)
        let error = registrationError?.takeRetainedValue()
        let alreadyRegistered = error.map {
            CFErrorGetCode($0) == CTFontManagerError.alreadyRegistered.rawValue
        } ?? false

        if !registered, !alreadyRegistered {
            let message = error.map { CFErrorCopyDescription($0) as String? } ?? nil
            logger.error("Failed to register font at \(url.path, privacy: .public): \(message ?? "unknown error", privacy: .public)")
        }
    }

    private static func facePostScriptName(for filename: String, bundle: Bundle) -> String? {
        guard let url = bundle.url(forResource: filename.replacingOccurrences(of: ".ttf", with: ""), withExtension: "ttf", subdirectory: "Fonts")
            ?? bundle.url(forResource: filename.replacingOccurrences(of: ".ttf", with: ""), withExtension: "ttf")
        else {
            return nil
        }

        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = descriptors.first
        else {
            return nil
        }

        return CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
    }

    private static func resolvedWeight(_ weight: NSFont.Weight) -> NSFont.Weight {
        switch weight {
        case ..<NSFont.Weight.medium:
            .regular
        case ..<NSFont.Weight.semibold:
            .medium
        default:
            .semibold
        }
    }

    private static func logUnavailableFace(_ name: String) {
        guard loggedUnavailableFaces.insert(name).inserted else { return }
        logger.error("Bundled font face unavailable: \(name, privacy: .public); using monospaced system fallback")
    }
}
