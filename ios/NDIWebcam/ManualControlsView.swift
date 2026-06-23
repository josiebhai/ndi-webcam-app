import UIKit
import AVFoundation

protocol ManualControlsDelegate: AnyObject {
    func manualControls(_ view: ManualControlsView, didChangeExposure bias: Float)
    func manualControls(_ view: ManualControlsView, didChangeISO iso: Float)
    func manualControls(_ view: ManualControlsView, didChangeShutter duration: CMTime)
    func manualControls(_ view: ManualControlsView, didChangeWhiteBalance temperature: Float)
    func manualControlsDidRequestFocusLock(_ view: ManualControlsView)
    func manualControlsDidRequestAutoFocus(_ view: ManualControlsView)
}

// MARK: - Ruler Slider

final class RulerSliderView: UIView {

    // Value range — set these before setting value.
    var minimumValue: Float = 0
    var maximumValue: Float = 1

    private var _value: Float = 0.5
    var value: Float {
        get { _value }
        set {
            _value = max(minimumValue, min(maximumValue, newValue))
            setNeedsDisplay()
        }
    }

    var onValueChanged: ((Float) -> Void)?

    // 40 ticks across the full value range, 10 pt apart → full range = 400 pt drag.
    private let tickCount = 40
    private let tickSpacing: CGFloat = 10
    private let smallTickHeight: CGFloat = 10
    private let largeTickHeight: CGFloat = 22
    private let majorEvery = 5

    private var dragStartValue: Float = 0
    private var dragStartX: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let range = maximumValue - minimumValue
        guard range > 0 else { return }

        let cx = rect.midX
        let midY = rect.midY
        let normalizedPos = CGFloat((value - minimumValue) / range)
        let totalPx = CGFloat(tickCount) * tickSpacing

        for i in 0...tickCount {
            let tickNorm = CGFloat(i) / CGFloat(tickCount)
            let tickX = cx + (tickNorm - normalizedPos) * totalPx
            guard tickX >= -tickSpacing && tickX <= rect.width + tickSpacing else { continue }

            let isMajor = (i % majorEvery == 0)
            let h = isMajor ? largeTickHeight : smallTickHeight
            let alpha: CGFloat = isMajor ? 0.85 : 0.4
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            ctx.setLineWidth(isMajor ? 1.5 : 1.0)
            ctx.move(to: CGPoint(x: tickX, y: midY - h / 2))
            ctx.addLine(to: CGPoint(x: tickX, y: midY + h / 2))
            ctx.strokePath()
        }

        // Fixed yellow center indicator
        let lineH = largeTickHeight + 10
        ctx.setStrokeColor(UIColor.systemYellow.cgColor)
        ctx.setLineWidth(2.5)
        ctx.move(to: CGPoint(x: cx, y: midY - lineH / 2))
        ctx.addLine(to: CGPoint(x: cx, y: midY + lineH / 2))
        ctx.strokePath()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let range = maximumValue - minimumValue
        let totalPx = CGFloat(tickCount) * tickSpacing

        switch gesture.state {
        case .began:
            dragStartValue = value
            dragStartX = gesture.location(in: self).x
        case .changed:
            let dx = gesture.location(in: self).x - dragStartX
            let delta = Float(dx / totalPx) * range
            value = max(minimumValue, min(maximumValue, dragStartValue + delta))
            onValueChanged?(value)
        default:
            break
        }
    }
}

// MARK: - ManualControlsView

final class ManualControlsView: UIView {

    // MARK: Public

    weak var delegate: ManualControlsDelegate?

    // Updated from AVCaptureDevice.activeFormat after camera is configured.
    var isoRange: ClosedRange<Float> = 50...3200
    var shutterRange: (min: CMTime, max: CMTime) = (
        CMTimeMake(value: 1, timescale: 8000),
        CMTimeMake(value: 1, timescale: 3)
    )

    // MARK: Private

    private enum Parameter: CaseIterable {
        case ev, iso, shutter, whiteBalance

        var title: String {
            switch self {
            case .ev:           return "EV"
            case .iso:          return "ISO"
            case .shutter:      return "SS"
            case .whiteBalance: return "WB"
            }
        }

        var label: String {
            switch self {
            case .ev:           return "EXPOSURE"
            case .iso:          return "ISO"
            case .shutter:      return "SHUTTER"
            case .whiteBalance: return "WHITE BAL"
            }
        }
    }

    private var selectedParam: Parameter = .ev
    private var paramButtons: [Parameter: UIButton] = [:]
    private let ruler      = RulerSliderView()
    private let valueLabel = UILabel()
    private let paramLabel = UILabel()

    // MARK: Init

    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = UIColor(white: 0, alpha: 0.78)
        layer.cornerRadius = 18
        layer.masksToBounds = true

        // Parameter selector row
        let buttonRow = UIStackView()
        buttonRow.axis = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 4

        for (index, param) in Parameter.allCases.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(param.title, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            btn.tintColor = .systemGray
            btn.layer.cornerRadius = 14
            btn.tag = index
            btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
            btn.addTarget(self, action: #selector(paramTapped(_:)), for: .touchUpInside)
            paramButtons[param] = btn
            buttonRow.addArrangedSubview(btn)
        }

        // Thin horizontal divider
        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        // Value row: large yellow number + gray parameter name
        valueLabel.textColor     = .systemYellow
        valueLabel.font          = .monospacedDigitSystemFont(ofSize: 24, weight: .medium)

        paramLabel.textColor     = UIColor.white.withAlphaComponent(0.5)
        paramLabel.font          = .systemFont(ofSize: 12, weight: .semibold)
        paramLabel.textAlignment = .right

        let valueRow = UIStackView(arrangedSubviews: [valueLabel, paramLabel])
        valueRow.axis      = .horizontal
        valueRow.alignment = .bottom
        valueRow.spacing   = 8

        // Ruler
        ruler.heightAnchor.constraint(equalToConstant: 44).isActive = true
        ruler.onValueChanged = { [weak self] pos in self?.rulerMoved(pos) }

        // Focus row
        let lockBtn = makeTextButton("Lock Focus", color: .white)
        lockBtn.addTarget(self, action: #selector(lockFocus), for: .touchUpInside)
        let autoBtn = makeTextButton("Auto", color: .systemGray)
        autoBtn.addTarget(self, action: #selector(autoFocus), for: .touchUpInside)
        let focusRow = UIStackView(arrangedSubviews: [lockBtn, autoBtn])
        focusRow.axis = .horizontal
        focusRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [buttonRow, divider, valueRow, ruler, focusRow])
        stack.axis    = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])

        select(.ev)
    }

    // MARK: Parameter selection

    @objc private func paramTapped(_ sender: UIButton) {
        select(Parameter.allCases[sender.tag])
    }

    private func select(_ param: Parameter) {
        selectedParam = param
        paramLabel.text = param.label

        paramButtons.forEach { key, btn in
            let on = (key == param)
            btn.tintColor       = on ? .systemYellow : .systemGray
            btn.backgroundColor = on ? UIColor.systemYellow.withAlphaComponent(0.15) : .clear
        }

        switch param {
        case .ev:
            ruler.minimumValue = -3;    ruler.maximumValue = 3;    ruler.value = 0
        case .iso:
            ruler.minimumValue = 0;     ruler.maximumValue = 1;    ruler.value = 0
        case .shutter:
            ruler.minimumValue = 0;     ruler.maximumValue = 1;    ruler.value = 0.3
        case .whiteBalance:
            ruler.minimumValue = 2000;  ruler.maximumValue = 8000; ruler.value = 5500
        }
        refreshLabel()
    }

    // MARK: Ruler callback

    private func rulerMoved(_ pos: Float) {
        refreshLabel()
        switch selectedParam {
        case .ev:
            delegate?.manualControls(self, didChangeExposure: pos)

        case .iso:
            let iso = isoRange.lowerBound + pos * (isoRange.upperBound - isoRange.lowerBound)
            delegate?.manualControls(self, didChangeISO: iso)

        case .shutter:
            let minS = CMTimeGetSeconds(shutterRange.min)
            let maxS = CMTimeGetSeconds(shutterRange.max)
            let secs = exp(log(minS) + Double(pos) * (log(maxS) - log(minS)))
            delegate?.manualControls(self, didChangeShutter: CMTimeMakeWithSeconds(secs, preferredTimescale: 1_000_000))

        case .whiteBalance:
            delegate?.manualControls(self, didChangeWhiteBalance: pos)
        }
    }

    private func refreshLabel() {
        let v = ruler.value
        switch selectedParam {
        case .ev:
            valueLabel.text = v >= 0 ? String(format: "+%.1f", v) : String(format: "%.1f", v)

        case .iso:
            let iso = isoRange.lowerBound + v * (isoRange.upperBound - isoRange.lowerBound)
            valueLabel.text = "\(Int(iso))"

        case .shutter:
            let minS = CMTimeGetSeconds(shutterRange.min)
            let maxS = CMTimeGetSeconds(shutterRange.max)
            let secs = exp(log(minS) + Double(v) * (log(maxS) - log(minS)))
            let frac = 1.0 / secs
            valueLabel.text = frac >= 2 ? "1/\(Int(frac))s" : String(format: "%.1fs", secs)

        case .whiteBalance:
            valueLabel.text = "\(Int(v))K"
        }
    }

    // MARK: Focus

    @objc private func lockFocus() { delegate?.manualControlsDidRequestFocusLock(self) }
    @objc private func autoFocus() { delegate?.manualControlsDidRequestAutoFocus(self) }

    // MARK: Helper

    private func makeTextButton(_ title: String, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.tintColor = color
        btn.titleLabel?.font = .systemFont(ofSize: 13)
        return btn
    }
}

// MARK: - Focus reticle (shown at tap point)

final class FocusReticleView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.borderColor = UIColor.systemYellow.cgColor
        layer.borderWidth = 1.5
        backgroundColor   = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(at center: CGPoint, in parent: UIView) {
        frame = CGRect(x: 0, y: 0, width: 70, height: 70)
        self.center = center
        alpha     = 0
        transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        parent.addSubview(self)

        UIView.animate(withDuration: 0.2, animations: {
            self.alpha     = 1
            self.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.6, delay: 0.8, animations: {
                self.alpha = 0
            }) { _ in
                self.removeFromSuperview()
            }
        }
    }
}
