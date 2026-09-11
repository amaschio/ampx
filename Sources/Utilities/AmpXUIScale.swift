import SwiftUI

enum AmpXUIScaleLevel: CGFloat, CaseIterable, Identifiable {
    case standard = 1.0
    case extraLarge = 1.5
    case huge = 2.0

    var id: CGFloat {
        rawValue
    }

    var label: String {
        switch self {
        case .standard: "100%"
        case .extraLarge: "150%"
        case .huge: "200%"
        }
    }
}

@MainActor
final class AmpXUIScale: ObservableObject {
    static let shared = AmpXUIScale()
    static let basePanelWidth: CGFloat = AmpXMetrics.panelWidth
    static let baseMainPlayerHeight: CGFloat = AmpXMetrics.mainPlayerHeight
    private static let userDefaultsKey = "AmpXUIScale"

    @Published private(set) var level: AmpXUIScaleLevel

    var scale: CGFloat {
        self.level.rawValue
    }

    var panelWidth: CGFloat {
        Self.basePanelWidth * self.scale
    }

    func size(_ points: CGFloat) -> CGFloat {
        points * self.scale
    }

    private init() {
        let saved = UserDefaults.standard.double(forKey: Self.userDefaultsKey)
        if saved > 0, let level = AmpXUIScaleLevel(rawValue: CGFloat(saved)) {
            self.level = level
        } else if saved > 0 {
            // Migrate removed levels (e.g. former 1.25) to the nearest remaining option.
            self.level = Self.nearestLevel(to: CGFloat(saved))
            UserDefaults.standard.set(self.level.rawValue, forKey: Self.userDefaultsKey)
        } else {
            self.level = .standard
        }
    }

    func setLevel(_ level: AmpXUIScaleLevel) {
        self.level = level
        UserDefaults.standard.set(level.rawValue, forKey: Self.userDefaultsKey)
    }

    /// Maps a legacy or unknown scale factor onto the closest current `AmpXUIScaleLevel`.
    /// Ties prefer the larger level so users who opted above 100% stay enlarged.
    nonisolated static func nearestLevel(to value: CGFloat) -> AmpXUIScaleLevel {
        let sorted = AmpXUIScaleLevel.allCases.sorted { $0.rawValue < $1.rawValue }
        guard let firstAbove = sorted.first(where: { $0.rawValue >= value }) else {
            return sorted.last ?? .standard
        }
        if let index = sorted.firstIndex(of: firstAbove), index > 0 {
            let below = sorted[index - 1]
            if abs(below.rawValue - value) < abs(firstAbove.rawValue - value) {
                return below
            }
        }
        return firstAbove
    }
}

private struct AmpXUIScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var winampUIScale: CGFloat {
        get { self[AmpXUIScaleKey.self] }
        set { self[AmpXUIScaleKey.self] = newValue }
    }
}

extension View {
    func winampFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design _: Font.Design = .default,
        scale: CGFloat
    ) -> some View {
        font(AmpXTypography.font(size: size * scale, weight: weight))
    }
}
