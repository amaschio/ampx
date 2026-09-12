import AppKit

@main
enum AmpXMain {
    static let newUIKey = "AmpXNewUI"

    static func usesNewUI(defaults: UserDefaults) -> Bool {
        guard let value = defaults.object(forKey: newUIKey) else { return false }
        if let bool = value as? Bool { return bool }
        if let string = value as? String {
            switch string.lowercased() {
            case "yes", "true", "1":
                return true
            default:
                return false
            }
        }
        return defaults.bool(forKey: newUIKey)
    }

    static func main() {
        if !isRunningUnderTest, usesNewUI(defaults: .standard) {
            let app = NSApplication.shared
            let delegate = AmpXAppDelegate()
            app.delegate = delegate
            withExtendedLifetime(delegate) { app.run() }
        } else {
            AmpXApp.main()
        }
    }

    private static var isRunningUnderTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
