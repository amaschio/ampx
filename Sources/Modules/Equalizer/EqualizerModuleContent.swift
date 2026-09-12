import AppKit
import Combine
import CoreGraphics

final class EqualizerModuleContent: AmpXModuleContent {
    private static let eqOnToggle = CGRect(x: 15.0, y: 14.0, width: 26.0, height: 18.0)
    private static let eqAutoToggle = CGRect(x: 43.0, y: 14.0, width: 32.0, height: 18.0)
    private static let eqPresetsButton = CGRect(x: 418.0, y: 14.0, width: 54.0, height: 18.0)

    private static let sliderTrackWidth: CGFloat = 18
    private static let decibelRange: ClosedRange<Double> = -12 ... 12

    private let audioPlayer: AudioPlayer
    private let onToggle: AmpXButton
    private let autoToggle: AmpXButton
    private let presetsButton: AmpXButton
    private let preampSlider: AmpXSlider
    private let curveView: EQCurveView
    private var bandSliders: [AmpXSlider] = []
    private var cancellables = Set<AnyCancellable>()
    private let presetsMenuTarget = EQPresetsMenuTarget()

    init(skin: any AmpXSkin, audioPlayer: AudioPlayer) {
        self.audioPlayer = audioPlayer
        self.onToggle = AmpXButton(skin: skin)
        self.autoToggle = AmpXButton(skin: skin)
        self.presetsButton = AmpXButton(skin: skin)
        self.preampSlider = AmpXSlider(skin: skin)
        self.curveView = EQCurveView(skin: skin)
        super.init(skin: skin)
        presetsMenuTarget.audioPlayer = audioPlayer
        configureControls()
        bindModels()
        refreshControlState(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureControls() {
        onToggle.label = "ON"
        onToggle.showsActiveIndicator = true
        onToggle.accessibilityTitle = "Equalizer on"
        onToggle.action = { [weak audioPlayer] in
            guard let audioPlayer else { return }
            audioPlayer.setEQEnabled(!audioPlayer.eqEnabled)
        }

        autoToggle.label = "AUTO"
        autoToggle.showsActiveIndicator = true
        autoToggle.accessibilityTitle = "Equalizer auto"
        autoToggle.action = { [weak audioPlayer] in
            guard let audioPlayer else { return }
            audioPlayer.setEQAutoEnabled(!audioPlayer.eqAutoEnabled)
        }

        presetsButton.label = "PRESETS"
        presetsButton.accessibilityTitle = "Equalizer presets"
        presetsButton.action = { [weak self] in
            self?.showPresetsMenu()
        }

        preampSlider.isVertical = true
        preampSlider.range = Self.decibelRange
        preampSlider.step = 1
        preampSlider.showsGradient = true
        preampSlider.showsThumbGrip = true
        preampSlider.accessibilityTitle = "Preamp"
        preampSlider.onChange = { [weak audioPlayer] db in
            audioPlayer?.setEQPreamp(EQValueMapping.normalized(decibels: Float(db)))
        }

        let row = AmpXMetrics.eqBandRow
        for index in 0 ..< AmpXEQBands.bandCount {
            let centerX = row.minX + AmpXEQBands.bandCenterX(bandIndex: index, width: row.width)
            let track = CGRect(
                x: centerX - Self.sliderTrackWidth / 2,
                y: row.minY,
                width: Self.sliderTrackWidth,
                height: row.height
            )
            let slider = AmpXSlider(skin: skin)
            slider.frame = track
            slider.isVertical = true
            slider.range = Self.decibelRange
            slider.step = 1
            slider.showsGradient = true
            slider.showsThumbGrip = true
            slider.accessibilityTitle = "\(AmpXEQBands.displayLabels[index]) band"
            slider.onChange = { [weak audioPlayer] db in
                audioPlayer?.setEQBand(index, gain: Float(db))
            }
            bandSliders.append(slider)
            addSubview(slider)
        }

        curveView.frame = AmpXMetrics.eqCurve

        for control in [curveView, onToggle, autoToggle, presetsButton, preampSlider] {
            addSubview(control)
        }
        layoutControls()
    }

    private func bindModels() {
        audioPlayer.$eqEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.onToggle.isActive = enabled
            }
            .store(in: &cancellables)

        audioPlayer.$eqAutoEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.autoToggle.isActive = enabled
            }
            .store(in: &cancellables)

        audioPlayer.$eqBandValues
            .receive(on: DispatchQueue.main)
            .sink { [weak self] values in
                self?.updateBandSliders(from: values)
                self?.updateCurve(animated: true)
            }
            .store(in: &cancellables)

        audioPlayer.$eqPreampValue
            .receive(on: DispatchQueue.main)
            .sink { [weak self] normalized in
                self?.updatePreampSlider(from: normalized)
                self?.updateCurve(animated: true)
            }
            .store(in: &cancellables)

        audioPlayer.$eqPresetsRevision
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.presetsMenuTarget.presets = self?.audioPlayer.eqPresets() ?? []
            }
            .store(in: &cancellables)
    }

    private func refreshControlState(animated: Bool) {
        onToggle.isActive = audioPlayer.eqEnabled
        autoToggle.isActive = audioPlayer.eqAutoEnabled
        updateBandSliders(from: audioPlayer.eqBandValues)
        updatePreampSlider(from: audioPlayer.eqPreampValue)
        presetsMenuTarget.presets = audioPlayer.eqPresets()
        updateCurve(animated: animated)
    }

    private func updateBandSliders(from values: [Float]) {
        for index in 0 ..< bandSliders.count where index < values.count {
            let db = EQValueMapping.decibels(normalized: values[index])
            bandSliders[index].setValue(Double(db), sendChange: false)
        }
    }

    private func updatePreampSlider(from normalized: Float) {
        let db = EQValueMapping.decibels(normalized: normalized)
        preampSlider.setValue(Double(db), sendChange: false)
    }

    private func updateCurve(animated: Bool) {
        curveView.setCurve(
            bandValues: audioPlayer.eqBandValues,
            preampValue: audioPlayer.eqPreampValue,
            animated: animated
        )
    }

    private func showPresetsMenu() {
        let menu = NSMenu()
        for preset in audioPlayer.eqPresets() {
            let item = NSMenuItem(
                title: preset.name,
                action: #selector(EQPresetsMenuTarget.applyPreset(_:)),
                keyEquivalent: ""
            )
            item.target = presetsMenuTarget
            item.representedObject = preset
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let loadItem = NSMenuItem(
            title: "Load EQF…",
            action: #selector(EQPresetsMenuTarget.loadEQF(_:)),
            keyEquivalent: ""
        )
        loadItem.target = presetsMenuTarget
        menu.addItem(loadItem)
        let resetItem = NSMenuItem(
            title: "Reset",
            action: #selector(EQPresetsMenuTarget.resetEQ(_:)),
            keyEquivalent: ""
        )
        resetItem.target = presetsMenuTarget
        menu.addItem(resetItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: presetsButton.bounds.height), in: presetsButton)
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutControls()
    }

    private func layoutControls() {
        onToggle.frame = Self.eqOnToggle
        autoToggle.frame = Self.eqAutoToggle
        presetsButton.frame = Self.eqPresetsButton
        preampSlider.frame = AmpXMetrics.eqPreamp
        curveView.frame = AmpXMetrics.eqCurve

        let row = AmpXMetrics.eqBandRow
        for index in 0 ..< bandSliders.count {
            let centerX = row.minX + AmpXEQBands.bandCenterX(bandIndex: index, width: row.width)
            bandSliders[index].frame = CGRect(
                x: centerX - Self.sliderTrackWidth / 2,
                y: row.minY,
                width: Self.sliderTrackWidth,
                height: row.height
            )
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let backingScale = window?.backingScaleFactor ?? 1

        drawCurveWell(in: context, backingScale: backingScale)
        drawDecibelScale(in: context)
        drawHorizontalGuides(in: context)
        drawSliderLabels(in: context)
    }

    private func drawCurveWell(in context: CGContext, backingScale: CGFloat) {
        let well = AmpXMetrics.eqCurve
        skin.displayWell(well, in: context, backingScale: backingScale)

        let midY = well.midY
        var x = well.minX + 1
        while x < well.maxX - 1 {
            context.setFillColor(skin.textDim.withAlphaComponent(0.55).cgColor)
            context.fill(CGRect(x: x, y: midY, width: 1, height: 1))
            x += 3
        }
    }

    private func drawDecibelScale(in context: CGContext) {
        let track = AmpXMetrics.eqPreamp
        let labels: [(String, CGFloat)] = [
            ("+12 dB", track.minY + 2),
            ("0 dB", track.midY - 4),
            ("-12 dB", track.maxY - 12),
        ]
        for (text, y) in labels {
            AmpXLabel(text: text, color: skin.orange, fontSize: 7, weight: .medium)
                .draw(in: CGRect(x: track.maxX + 2, y: y, width: 28, height: 10), context: context, skin: skin)
        }
    }

    private func drawHorizontalGuides(in context: CGContext) {
        let row = AmpXMetrics.eqBandRow
        let track = AmpXMetrics.eqPreamp
        let guideYs = [
            track.minY + 2,
            track.midY,
            track.maxY - 2,
        ]
        context.saveGState()
        context.setStrokeColor(skin.textDim.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [2, 2])
        for y in guideYs {
            context.move(to: CGPoint(x: row.minX, y: y))
            context.addLine(to: CGPoint(x: row.maxX, y: y))
        }
        context.strokePath()
        context.restoreGState()
    }

    private func drawSliderLabels(in context: CGContext) {
        let row = AmpXMetrics.eqBandRow
        let preampLabel = CGRect(
            x: AmpXMetrics.eqPreamp.minX - 4,
            y: row.maxY + 2,
            width: AmpXMetrics.eqPreamp.width + 8,
            height: 12
        )
        AmpXLabel(text: "PREAMP", color: skin.orange, fontSize: 7, weight: .medium, alignment: .center)
            .draw(in: preampLabel, context: context, skin: skin)

        for index in 0 ..< AmpXEQBands.bandCount {
            let centerX = row.minX + AmpXEQBands.bandCenterX(bandIndex: index, width: row.width)
            let labelRect = CGRect(x: centerX - 16, y: row.maxY + 2, width: 32, height: 12)
            AmpXLabel(
                text: AmpXEQBands.displayLabels[index],
                color: skin.orange,
                fontSize: 7,
                weight: .medium,
                alignment: .center
            )
            .draw(in: labelRect, context: context, skin: skin)
        }
    }
}

@MainActor
private final class EQPresetsMenuTarget: NSObject {
    weak var audioPlayer: AudioPlayer?
    var presets: [EQPreset] = []

    @objc func applyPreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? EQPreset else { return }
        audioPlayer?.applyEQPreset(preset)
    }

    @objc func loadEQF(_ sender: NSMenuItem) {
        audioPlayer?.importEQFPresets()
    }

    @objc func resetEQ(_ sender: NSMenuItem) {
        audioPlayer?.resetEQ()
    }
}
