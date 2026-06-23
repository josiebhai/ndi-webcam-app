import UIKit
import AVFoundation
import Combine

final class CameraViewController: UIViewController {

    // MARK: Dependencies

    private let ndiStreamer = NDIStreamer()
    private let audioManager = AudioManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: Capture

    private let captureSession = AVCaptureSession()
    private let videoOutput    = AVCaptureVideoDataOutput()
    private let audioOutput    = AVCaptureAudioDataOutput()
    private let captureQueue   = DispatchQueue(label: "com.ndiwebcam.capture", qos: .userInteractive)
    private var currentDevice: AVCaptureDevice?
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var usingFrontCamera = false

    // MARK: Settings

    private var targetFPS: Int32 = 30
    private var targetResolution: AVCaptureSession.Preset = .hd1920x1080

    // MARK: UI

    private let previewContainer = UIView()
    private let controlsOverlay  = UIView()
    private let streamButton     = UIButton(type: .system)
    private let switchButton     = UIButton(type: .system)
    private let torchButton      = UIButton(type: .system)
    private let settingsButton   = UIButton(type: .system)
    private let controlsToggle   = UIButton(type: .system)
    private let manualControls   = ManualControlsView()
    private let statusLabel      = UILabel()
    private let tallyView        = UIView()
    private var statusTimer: Timer?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "NDI Webcam"
        view.backgroundColor = .black
        setupUI()
        requestPermissions { [weak self] in
            self?.setupCaptureSession()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            captureQueue.async { self.captureSession.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        if ndiStreamer.isStreaming { stopStreaming() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewContainer.bounds
    }

    // MARK: Permissions

    private func requestPermissions(completion: @escaping () -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else { return }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                guard granted else { return }
                DispatchQueue.main.async { completion() }
            }
        }
    }

    // MARK: Capture Session Setup

    private func setupCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = targetResolution

        addCameraInput(front: false)
        addAudioInput()
        addVideoOutput()
        addAudioOutputs()

        captureSession.commitConfiguration()
        captureQueue.async { self.captureSession.startRunning() }
    }

    private func addCameraInput(front: Bool) {
        captureSession.inputs
            .compactMap { $0 as? AVCaptureDeviceInput }
            .filter { $0.device.hasMediaType(.video) }
            .forEach { captureSession.removeInput($0) }

        let position: AVCaptureDevice.Position = front ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input)
        else { return }

        captureSession.addInput(input)
        currentDevice = device
        usingFrontCamera = front

        configureFPS(device: device, fps: targetFPS)
    }

    private func addAudioInput() {
        guard let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input)
        else { return }
        captureSession.addInput(input)
    }

    private func addVideoOutput() {
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
    }

    private func addAudioOutputs() {
        audioOutput.setSampleBufferDelegate(self, queue: captureQueue)
        guard captureSession.canAddOutput(audioOutput) else { return }
        captureSession.addOutput(audioOutput)
    }

    private func configureFPS(device: AVCaptureDevice, fps: Int32) {
        guard let range = device.activeFormat.videoSupportedFrameRateRanges.first(where: {
            $0.maxFrameRate >= Double(fps)
        }) else { return }
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: fps)
            device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: fps)
            device.unlockForConfiguration()
        } catch {}
    }

    // MARK: Streaming

    @objc private func toggleStreaming() {
        ndiStreamer.isStreaming ? stopStreaming() : startStreaming()
    }

    private func startStreaming() {
        let sourceName = UserDefaults.standard.string(forKey: "sourceName") ?? UIDevice.current.name
        do {
            try ndiStreamer.start(sourceName: sourceName)
            streamButton.setTitle("Stop", for: .normal)
            streamButton.tintColor = .systemRed
            tallyView.backgroundColor = .systemRed
            tallyView.isHidden = false
            startStatusUpdates()
        } catch {
            showAlert("Stream Error", message: error.localizedDescription)
        }
    }

    private func stopStreaming() {
        ndiStreamer.stop()
        streamButton.setTitle("Go Live", for: .normal)
        streamButton.tintColor = .white
        tallyView.isHidden = true
        statusTimer?.invalidate()
        statusLabel.text = "Ready"
    }

    // MARK: Camera Controls

    @objc private func switchCamera() {
        captureSession.beginConfiguration()
        addCameraInput(front: !usingFrontCamera)
        captureSession.commitConfiguration()
        updateTorchButton()
    }

    @objc private func toggleTorch() {
        guard let device = currentDevice, device.hasTorch, !usingFrontCamera else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            device.unlockForConfiguration()
            updateTorchButton()
        } catch {}
    }

    private func updateTorchButton() {
        guard let device = currentDevice else { return }
        let active = device.hasTorch && !usingFrontCamera && device.torchMode == .on
        torchButton.tintColor = active ? .systemYellow : .white
        torchButton.isEnabled = !usingFrontCamera && (currentDevice?.hasTorch ?? false)
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(audioManager: audioManager), animated: true)
    }

    @objc private func toggleManualControls() {
        UIView.animate(withDuration: 0.25) {
            self.manualControls.isHidden.toggle()
        }
    }

    // MARK: Tap to Focus

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: previewContainer)
        let normalised = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        setFocusPoint(normalised)
    }

    private func setFocusPoint(_ point: CGPoint) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {}
    }

    // MARK: Status

    private func startStatusUpdates() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let count = self.ndiStreamer.connectedReceiverCount
            let suffix = count == 1 ? "receiver" : "receivers"
            self.statusLabel.text = "\(count) \(suffix)"
        }
    }

    private func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: UI Layout

    private func setupUI() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self, action: #selector(openSettings)
        )

        // Preview container fills the view
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewContainer)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewContainer.layer.addSublayer(previewLayer)

        // Tap-to-focus
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        previewContainer.addGestureRecognizer(tap)

        // Tally indicator
        tallyView.backgroundColor = .systemRed
        tallyView.layer.cornerRadius = 8
        tallyView.isHidden = true
        tallyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tallyView)

        // Status label
        statusLabel.text = "Ready"
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        // Bottom controls
        let bottomBar = UIStackView()
        bottomBar.axis = .horizontal
        bottomBar.spacing = 20
        bottomBar.alignment = .center
        bottomBar.distribution = .equalSpacing
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        configureButton(switchButton, systemImage: "arrow.triangle.2.circlepath.camera", action: #selector(switchCamera))
        configureButton(torchButton,  systemImage: "flashlight.off.fill", action: #selector(toggleTorch))
        configureButton(controlsToggle, systemImage: "slider.horizontal.3", action: #selector(toggleManualControls))

        streamButton.setTitle("Go Live", for: .normal)
        streamButton.tintColor = .white
        streamButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        streamButton.addTarget(self, action: #selector(toggleStreaming), for: .touchUpInside)

        bottomBar.addArrangedSubview(switchButton)
        bottomBar.addArrangedSubview(torchButton)
        bottomBar.addArrangedSubview(streamButton)
        bottomBar.addArrangedSubview(controlsToggle)

        // Manual controls panel
        manualControls.delegate = self
        manualControls.isHidden = true
        manualControls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(manualControls)

        NSLayoutConstraint.activate([
            previewContainer.topAnchor.constraint(equalTo: view.topAnchor),
            previewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            tallyView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            tallyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tallyView.widthAnchor.constraint(equalToConstant: 16),
            tallyView.heightAnchor.constraint(equalToConstant: 16),

            statusLabel.centerYAnchor.constraint(equalTo: tallyView.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: tallyView.leadingAnchor, constant: -8),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            bottomBar.heightAnchor.constraint(equalToConstant: 52),

            manualControls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            manualControls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            manualControls.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -12),
        ])
    }

    private func configureButton(_ button: UIButton, systemImage: String, action: Selector) {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: systemImage, withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: action, for: .touchUpInside)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate,
                                 AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard ndiStreamer.isStreaming else { return }
        if output === videoOutput {
            ndiStreamer.sendVideoFrame(sampleBuffer, fps: targetFPS)
        } else if output === audioOutput {
            ndiStreamer.sendAudioFrame(sampleBuffer)
        }
    }
}

// MARK: - ManualControlsDelegate

extension CameraViewController: ManualControlsDelegate {

    func manualControls(_ view: ManualControlsView, didChangeExposure bias: Float) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(bias)
            device.unlockForConfiguration()
        } catch {}
    }

    func manualControls(_ view: ManualControlsView, didChangeISO iso: Float) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: AVCaptureDevice.currentExposureDuration, iso: iso)
            device.unlockForConfiguration()
        } catch {}
    }

    func manualControls(_ view: ManualControlsView, didChangeShutter duration: CMTime) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: duration, iso: AVCaptureDevice.currentISO)
            device.unlockForConfiguration()
        } catch {}
    }

    func manualControls(_ view: ManualControlsView, didChangeWhiteBalance temperature: Float) {
        guard let device = currentDevice, device.isWhiteBalanceModeSupported(.locked) else { return }
        let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: temperature, tint: 0))
        do {
            try device.lockForConfiguration()
            device.setWhiteBalanceModeLocked(with: gains)
            device.unlockForConfiguration()
        } catch {}
    }

    func manualControlsDidRequestFocusLock(_ view: ManualControlsView) {
        guard let device = currentDevice, device.isFocusModeSupported(.locked) else { return }
        do {
            try device.lockForConfiguration()
            device.focusMode = .locked
            device.unlockForConfiguration()
        } catch {}
    }

    func manualControlsDidRequestAutoFocus(_ view: ManualControlsView) {
        guard let device = currentDevice, device.isFocusModeSupported(.continuousAutoFocus) else { return }
        do {
            try device.lockForConfiguration()
            device.focusMode = .continuousAutoFocus
            device.unlockForConfiguration()
        } catch {}
    }
}
