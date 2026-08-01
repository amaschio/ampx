import SwiftUI

enum WinampUIScaleLevel: CGFloat, CaseIterable, Identifiable {
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
final class WinampUIScale: ObservableObject {
    static let shared = WinampUIScale()
    static let basePanelWidth: CGFloat = WinampMetrics.panelWidth
    static let baseMainPlayerHeight: CGFloat = WinampMetrics.mainPlayerHeight
    private static let userDefaultsKey = "WinampUIScale"

    @Published private(set) var level: WinampUIScaleLevel

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
        if saved > 0, let level = WinampUIScaleLevel(rawValue: CGFloat(saved)) {
            self.level = level
        } else if saved > 0 {
            // Migrate removed levels (e.g. former 1.25) to the nearest remaining option.
            self.level = Self.nearestLevel(to: CGFloat(saved))
            UserDefaults.standard.set(self.level.rawValue, forKey: Self.userDefaultsKey)
        } else {
            self.level = .standard
        }
    }

    func setLevel(_ level: WinampUIScaleLevel) {
        self.level = level
        UserDefaults.standard.set(level.rawValue, forKey: Self.userDefaultsKey)
    }

    /// Maps a legacy or unknown scale factor onto the closest current `WinampUIScaleLevel`.
    /// Ties prefer the larger level so users who opted above 100% stay enlarged.
    nonisolated static func nearestLevel(to value: CGFloat) -> WinampUIScaleLevel {
        let sorted = WinampUIScaleLevel.allCases.sorted { $0.rawValue < $1.rawValue }
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

private struct WinampUIScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var winampUIScale: CGFloat {
        get { self[WinampUIScaleKey.self] }
        set { self[WinampUIScaleKey.self] = newValue }
    }
}

extension View {
    func winampFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design _: Font.Design = .default,
        scale: CGFloat
    ) -> some View {
        font(WinampTypography.font(size: size * scale, weight: weight))
    }
}
