import Foundation

enum EQValueMapping {
    static let maxDecibels: Float = 12

    static func decibels(normalized: Float) -> Float {
        let db = normalized * maxDecibels
        return min(max(db, -maxDecibels), maxDecibels)
    }

    static func normalized(decibels: Float) -> Float {
        let clamped = min(max(decibels, -maxDecibels), maxDecibels)
        return clamped / maxDecibels
    }
}
