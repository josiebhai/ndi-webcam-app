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

final class ManualControlsView: UIView {

    weak var delegate: ManualControlsDelegate?

    // MARK: Subviews

    private let stackView   = UIStackView()
    private let exposureRow = makeRow(label: "EV", minValue: -3, maxValue: 3, initialValue: 0)
    private let isoRow      = makeRow(label: "ISO", minValue: 0, maxValue: 1, initialValue: 0)
    private let shutterRow  = makeRow(label: "Shutter", minValue: 0, maxValue: 1, initialValue: 0.5)
    private let wbRow       = makeRow(label: "WB (K)", minValue: 2000, maxValue: 8000, initialValue: 5500)
    private let focusButton = UIButton(type: .system)
    private let autoFocusButton = UIButton(type: .system)

    // Ranges are populated from AVCaptureDevice after the camera is set up.
    var isoRange: (min: Float, max: Float) = (25, 3200)
    var shutterRange: (min: CMTime, max: CMTime) = (
        CMTimeMake(value: 1, timescale: 8000),
        CMTimeMake(value: 1, timescale: 2)
    )

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        layer.cornerRadius = 12

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])

        stackView.addArrangedSubview(exposureRow.container)
        stackView.addArrangedSubview(isoRow.container)
        stackView.addArrangedSubview(shutterRow.container)
        stackView.addArrangedSubview(wbRow.container)

        let focusRow = UIStackView()
        focusRow.axis = .horizontal
        focusRow.spacing = 8
        focusRow.distribution = .fillEqually

        focusButton.setTitle("Lock Focus", for: .normal)
        focusButton.tintColor = .white
        focusButton.addTarget(self, action: #selector(lockFocus), for: .touchUpInside)

        autoFocusButton.setTitle("Auto Focus", for: .normal)
        autoFocusButton.tintColor = .systemGray
        autoFocusButton.addTarget(self, action: #selector(autoFocus), for: .touchUpInside)

        focusRow.addArrangedSubview(focusButton)
        focusRow.addArrangedSubview(autoFocusButton)
        stackView.addArrangedSubview(focusRow)

        exposureRow.slider.addTarget(self, action: #selector(exposureChanged(_:)), for: .valueChanged)
        isoRow.slider.addTarget(self, action: #selector(isoChanged(_:)), for: .valueChanged)
        shutterRow.slider.addTarget(self, action: #selector(shutterChanged(_:)), for: .valueChanged)
        wbRow.slider.addTarget(self, action: #selector(wbChanged(_:)), for: .valueChanged)
    }

    // MARK: Actions

    @objc private func exposureChanged(_ slider: UISlider) {
        delegate?.manualControls(self, didChangeExposure: slider.value)
        exposureRow.valueLabel.text = String(format: "%.1f", slider.value)
    }

    @objc private func isoChanged(_ slider: UISlider) {
        let iso = isoRange.min + slider.value * (isoRange.max - isoRange.min)
        delegate?.manualControls(self, didChangeISO: iso)
        isoRow.valueLabel.text = String(format: "%.0f", iso)
    }

    @objc private func shutterChanged(_ slider: UISlider) {
        let minSeconds = CMTimeGetSeconds(shutterRange.min)
        let maxSeconds = CMTimeGetSeconds(shutterRange.max)
        let seconds = minSeconds + Double(slider.value) * (maxSeconds - minSeconds)
        let time = CMTimeMakeWithSeconds(seconds, preferredTimescale: 1_000_000)
        delegate?.manualControls(self, didChangeShutter: time)
        let fraction = 1.0 / seconds
        shutterRow.valueLabel.text = "1/\(Int(fraction))"
    }

    @objc private func wbChanged(_ slider: UISlider) {
        delegate?.manualControls(self, didChangeWhiteBalance: slider.value)
        wbRow.valueLabel.text = "\(Int(slider.value))K"
    }

    @objc private func lockFocus() {
        delegate?.manualControlsDidRequestFocusLock(self)
    }

    @objc private func autoFocus() {
        delegate?.manualControlsDidRequestAutoFocus(self)
    }
}

// MARK: - Row builder

private struct ControlRow {
    let container: UIView
    let slider: UISlider
    let valueLabel: UILabel
}

private func makeRow(label: String, minValue: Float, maxValue: Float, initialValue: Float) -> ControlRow {
    let container = UIView()
    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 8
    row.translatesAutoresizingMaskIntoConstraints = false

    let nameLabel = UILabel()
    nameLabel.text = label
    nameLabel.textColor = .white
    nameLabel.font = .systemFont(ofSize: 12)
    nameLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true

    let slider = UISlider()
    slider.minimumValue = minValue
    slider.maximumValue = maxValue
    slider.value = initialValue
    slider.tintColor = .white

    let valueLabel = UILabel()
    valueLabel.textColor = .systemGray
    valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    valueLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
    valueLabel.textAlignment = .right

    row.addArrangedSubview(nameLabel)
    row.addArrangedSubview(slider)
    row.addArrangedSubview(valueLabel)

    container.addSubview(row)
    NSLayoutConstraint.activate([
        row.topAnchor.constraint(equalTo: container.topAnchor),
        row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        row.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        row.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    return ControlRow(container: container, slider: slider, valueLabel: valueLabel)
}
