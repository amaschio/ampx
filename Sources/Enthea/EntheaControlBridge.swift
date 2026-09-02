import Foundation
import WebKit

/// Swift → JS control surface for `window.winampEnthea` (mode, autopilot, dose, reseed).
/// Waits for `ready` before issuing commands so early calls are not silently dropped.
final class EntheaControlBridge: @unchecked Sendable {
    private let lock = NSLock()
    private weak var evaluator: EntheaJavaScriptEvaluating?
    private var statusHandler: (@Sendable (EntheaHostStatus) -> Void)?

    init(evaluator: EntheaJavaScriptEvaluating? = nil) {
        self.evaluator = evaluator
    }

    func attach(evaluator: EntheaJavaScriptEvaluating?) {
        self.lock.lock()
        self.evaluator = evaluator
        self.lock.unlock()
    }

    func onStatus(_ handler: (@Sendable (EntheaHostStatus) -> Void)?) {
        self.lock.lock()
        self.statusHandler = handler
        self.lock.unlock()
    }

    func stepMode(_ delta: Int) {
        self.evaluate("window.winampEnthea&&window.winampEnthea.stepMode(\(delta));")
        self.refreshStatus()
    }

    func setMode(_ id: Int) {
        self.evaluate("window.winampEnthea&&window.winampEnthea.setMode(\(id));")
        self.refreshStatus()
    }

    func setAutopilot(_ on: Bool) {
        self.evaluate("window.winampEnthea&&window.winampEnthea.setAutopilot(\(on ? "true" : "false"));")
        self.refreshStatus()
    }

    func nudgeDose(_ delta: Double) {
        self.evaluate("window.winampEnthea&&window.winampEnthea.setDose(\(delta));")
    }

    func reseed() {
        self.evaluate("window.winampEnthea&&window.winampEnthea.reseed();")
    }

    func fireDrop() {
        self.evaluate("window.winampEnthea&&window.winampEnthea.fireDrop();")
    }

    /// Restore persisted prefs once `bridge.js` reports ready (poll briefly).
    func restoreWhenReady(modeID: Int, autopilot: Bool) {
        self.pollReady(attemptsLeft: 40) { [weak self] in
            guard let self else { return }
            self.setMode(modeID)
            self.setAutopilot(autopilot)
            self.refreshStatus()
        }
    }

    func refreshStatus() {
        self.evaluateReturning(
            "(function(){return window.winampEnthea&&window.winampEnthea.getStatus?window.winampEnthea.getStatus():null;})()"
        ) { [weak self] value in
            guard let self, let status = EntheaHostStatus(jsValue: value) else { return }
            self.lock.lock()
            let handler = self.statusHandler
            self.lock.unlock()
            handler?(status)
        }
    }

    private func pollReady(attemptsLeft: Int, onReady: @escaping @Sendable () -> Void) {
        guard attemptsLeft > 0 else { return }
        self.evaluateReturning("!!(window.winampEnthea&&window.winampEnthea.ready)") { [weak self] value in
            if (value as? Bool) == true {
                onReady()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self?.pollReady(attemptsLeft: attemptsLeft - 1, onReady: onReady)
            }
        }
    }

    private func evaluate(_ script: String) {
        self.lock.lock()
        let evaluator = self.evaluator
        self.lock.unlock()
        evaluator?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func evaluateReturning(_ script: String, completion: @escaping @Sendable (Any?) -> Void) {
        self.lock.lock()
        let evaluator = self.evaluator
        self.lock.unlock()
        evaluator?.evaluateJavaScript(script) { result, _ in
            completion(result)
        }
    }
}

struct EntheaHostStatus: Sendable, Equatable {
    var modeID: Int
    var modeName: String
    var autopilot: Bool
    var dose: Double

    init(modeID: Int, modeName: String, autopilot: Bool, dose: Double) {
        self.modeID = modeID
        self.modeName = modeName
        self.autopilot = autopilot
        self.dose = dose
    }

    init?(jsValue: Any?) {
        guard let dict = jsValue as? [String: Any] else { return nil }
        let modeID = (dict["mode"] as? NSNumber)?.intValue ?? (dict["mode"] as? Int) ?? 0
        let modeName = (dict["name"] as? String) ?? "ENTHEA"
        let autopilot = (dict["autopilot"] as? Bool) ?? false
        let dose = (dict["dose"] as? NSNumber)?.doubleValue ?? (dict["dose"] as? Double) ?? 0.45
        self.init(modeID: modeID, modeName: modeName, autopilot: autopilot, dose: dose)
    }
}

/// Observable strip state shared between Classic chrome and the WebView host.
@MainActor
final class EntheaPanelController: ObservableObject {
    @Published var modeID: Int = 0
    @Published var modeName: String = "ENTHEA"
    @Published var autopilot: Bool = true
    @Published var dose: Double = 0.45

    let preferences = EntheaPreferences()
    let controlBridge = EntheaControlBridge()
    private var statusTimer: Timer?
    private var didBindHost = false

    init() {
        self.modeID = self.preferences.modeID
        self.autopilot = self.preferences.autopilot
        self.controlBridge.onStatus { [weak self] status in
            Task { @MainActor in
                self?.apply(status)
            }
        }
    }

    var stripTitle: String {
        if self.autopilot {
            return "ENTHEA • AUTOPILOT"
        }
        let name = self.modeName.isEmpty ? "ENTHEA" : self.modeName.uppercased()
        return "ENTHEA • \(name)"
    }

    func attach(evaluator: EntheaJavaScriptEvaluating) {
        self.controlBridge.attach(evaluator: evaluator)
    }

    func hostDidFinishLoad() {
        if self.didBindHost {
            self.controlBridge.refreshStatus()
            return
        }
        self.didBindHost = true
        self.controlBridge.restoreWhenReady(
            modeID: self.preferences.modeID,
            autopilot: self.preferences.autopilot
        )
        self.startStatusPolling()
    }

    func hostDidTeardown() {
        self.didBindHost = false
        self.statusTimer?.invalidate()
        self.statusTimer = nil
    }

    func previousMode() {
        self.preferences.autopilot = false
        self.autopilot = false
        self.controlBridge.setAutopilot(false)
        self.controlBridge.stepMode(-1)
    }

    func nextMode() {
        self.preferences.autopilot = false
        self.autopilot = false
        self.controlBridge.setAutopilot(false)
        self.controlBridge.stepMode(1)
    }

    func toggleAutopilot() {
        let next = !self.autopilot
        self.autopilot = next
        self.preferences.autopilot = next
        self.controlBridge.setAutopilot(next)
    }

    func nudgeDose(_ delta: Double) {
        self.controlBridge.nudgeDose(delta)
        self.controlBridge.refreshStatus()
    }

    func reseed() {
        self.controlBridge.reseed()
    }

    func fireDrop() {
        self.controlBridge.fireDrop()
    }

    private func apply(_ status: EntheaHostStatus) {
        self.modeID = status.modeID
        self.modeName = status.modeName
        self.autopilot = status.autopilot
        self.dose = status.dose
        self.preferences.modeID = status.modeID
        self.preferences.autopilot = status.autopilot
    }

    private func startStatusPolling() {
        self.statusTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.controlBridge.refreshStatus()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.statusTimer = timer
    }
}
