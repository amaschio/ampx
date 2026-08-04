import Foundation

/// UserDefaults-backed ENTHEA host preferences (injectable for tests).
struct EntheaPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private static let warningKey = "entheaPhotosensitiveWarningAccepted"
    private static let autopilotKey = "entheaAutopilot"
    private static let modeKey = "entheaModeID"
    private static let forceMetalBodyKey = "entheaForceMetalBody"

    var photosensitiveWarningAccepted: Bool {
        get { self.defaults.bool(forKey: Self.warningKey) }
        nonmutating set { self.defaults.set(newValue, forKey: Self.warningKey) }
    }

    var autopilot: Bool {
        get {
            if self.defaults.object(forKey: Self.autopilotKey) == nil { return true }
            return self.defaults.bool(forKey: Self.autopilotKey)
        }
        nonmutating set { self.defaults.set(newValue, forKey: Self.autopilotKey) }
    }

    var modeID: Int {
        get { self.defaults.integer(forKey: Self.modeKey) }
        nonmutating set { self.defaults.set(newValue, forKey: Self.modeKey) }
    }

    /// Kill switch for Task 5 — force Metal body even if Enthea is default.
    var forceMetalBody: Bool {
        get { self.defaults.bool(forKey: Self.forceMetalBodyKey) }
        nonmutating set { self.defaults.set(newValue, forKey: Self.forceMetalBodyKey) }
    }
}

enum EntheaBackingScale {
    /// Measured Task −1 budget: 60 fps in all modes at ≤ ~2.0 Mpx backing pixels.
    static let pixelBudget: Double = 2_000_000

    static func scale(forSize size: CGSize, screenScale: CGFloat) -> CGFloat {
        let width = Double(size.width)
        let height = Double(size.height)
        guard width > 0, height > 0 else { return 1 }
        let fit = (Self.pixelBudget / (width * height)).squareRoot()
        let clamped = min(max(min(Double(screenScale), fit), 1.0), 2.0)
        return CGFloat(clamped)
    }
}
