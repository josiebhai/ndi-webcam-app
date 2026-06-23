import UIKit
import AVFoundation
import Combine

final class CameraViewController: UIViewController {

    // MARK: Dependencies

    private let ndiStreamer   = NDIStreamer()
    private let audioManager = AudioManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: Capture

    private let captureSession = AVCaptureSession()
    private let videoOutput    = AVCaptureVideoDataOutput()
    private let audioOutput    = AVCaptureAudioDataOutput()
    private let captureQueue   = DispatchQueue(label: "com.ndiwebcam.capture", qos: .userInteractive)
    private let configQueue    = DispatchQueue(label: "com.ndiwebcam.config",  qos: .userInitiated)
    private var currentDevice: AVCaptureDevice?
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var usingFrontCamera = false
    private var micMuted = false

    // MARK: Settings

    private var targetFPS: Int32 = 30
    private var targetResolution: AVCaptureSession.Preset = .hd1920x1080

    // MARK: UI – Preview

    private let previewContainer = UIView()

    // MARK: UI – Top bar

    private let torchButton   = UIButton(type: .system)
    private let filterButton  = UIButton(type: .system)
    private let sourceButton  = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)

    // MARK: UI – Camera toolbar

    private let toolbarView  = UIView()
    private let tbTorchBtn   = UIButton(type: .system)
    private let tbFilterBtn  = UIButton(type: .system)
    private let tbMicBtn     = UIButton(type: .system)
    private let tbAspectBtn  = UIButton(type: .system)
    private let tbEVBtn      = UIButton(type: .system)
    private let tbTimerBtn   = UIButton(type: .system)

    // MARK: UI – Bottom controls

    private let streamButton     = UIButton(type: .custom)
    private let switchButton     = UIButton(type: .system)
    private let connectionsView  = UIView()
    private let connectionsLabel = UILabel()

    // MARK: UI – Manual controls

    private let manualControls = ManualControlsView()
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
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if !captureSession.isRunning {
            captureQueue.async { self.captureSession.startRunning() }
        }
        let sourceName = UserDefaults.standard.string(forKey: "sourceName") ?? UIDevice.current.name
        sourceButton.setTitle(sourceName, for: .normal)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        if captureSession.isRunning { captureSession.stopRunning() }
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
              let input  = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input)
        else { return }

        captureSession.addInput(input)
        currentDevice    = device
        usingFrontCamera = front

        configureFPS(device: device, fps: targetFPS)

        DispatchQueue.main.async { [weak self] in
            self?.updateDeviceRanges(device: device)
        }
    }

    private func addAudioInput() {
        guard let device = AVCaptureDevice.default(for: .audio),
              let input  = try? AVCaptureDeviceInput(device: device),
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
        guard device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
            $0.maxFrameRate >= Double(fps)
        }) else { return }
        configQueue.async {
            do {
                try device.lockForConfiguration()
                device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: fps)
                device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: fps)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    private func updateDeviceRanges(device: AVCaptureDevice) {
        let fmt = device.activeFormat
        manualControls.isoRange = fmt.minISO...fmt.maxISO

        let minDur = max(CMTimeGetSeconds(fmt.minExposureDuration), 1.0 / 8000)
        let maxDur = min(CMTimeGetSeconds(fmt.maxExposureDuration), 1.0 / 3)
        manualControls.shutterRange = (
            CMTimeMakeWithSeconds(minDur, preferredTimescale: 1_000_000),
            CMTimeMakeWithSeconds(maxDur, preferredTimescale: 1_000_000)
        )
    }

    // MARK: Streaming

    @objc private func toggleStreaming() {
        ndiStreamer.isStreaming ? stopStreaming() : startStreaming()
    }

    private func startStreaming() {
        let sourceName = UserDefaults.standard.string(forKey: "sourceName") ?? UIDevice.current.name
        do {
            try ndiStreamer.start(sourceName: sourceName)
            streamButton.backgroundColor = .systemRed
            streamButton.layer.borderColor = UIColor.systemRed.cgColor
            previewContainer.layer.borderWidth = 3
            previewContainer.layer.borderColor = UIColor.systemRed.cgColor
            startStatusUpdates()
        } catch {
            showAlert("Stream Error", message: error.localizedDescription)
        }
    }

    private func stopStreaming() {
        ndiStreamer.stop()
        streamButton.backgroundColor = .white
        streamButton.layer.borderColor = UIColor(white: 0.85, alpha: 1).cgColor
        previewContainer.layer.borderWidth = 0
        statusTimer?.invalidate()
        connectionsLabel.text = "0"
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
        let newMode: AVCaptureDevice.TorchMode = device.torchMode == .on ? .off : .on
        configQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                device.torchMode = newMode
                device.unlockForConfiguration()
            } catch {}
            DispatchQueue.main.async { self?.updateTorchButton() }
        }
    }

    private func updateTorchButton() {
        guard let device = currentDevice else { return }
        let active    = device.hasTorch && !usingFrontCamera && device.torchMode == .on
        let isEnabled = !usingFrontCamera && (currentDevice?.hasTorch ?? false)

        torchButton.tintColor        = active ? .systemYellow : .white
        torchButton.backgroundColor  = active
            ? UIColor.systemYellow.withAlphaComponent(0.25)
            : UIColor(white: 0.2, alpha: 0.75)
        torchButton.isEnabled        = isEnabled

        tbTorchBtn.tintColor  = active ? .systemYellow : .white
        tbTorchBtn.isEnabled  = isEnabled
    }

    @objc private func toggleMic() {
        micMuted.toggle()
        let imgName = micMuted ? "mic.slash.fill" : "mic.slash"
        let config  = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        tbMicBtn.setImage(UIImage(systemName: imgName, withConfiguration: config), for: .normal)
        tbMicBtn.tintColor = micMuted ? .systemOrange : .white
    }

    @objc private func toggleFilter() {
        let isActive = filterButton.tintColor == UIColor.systemYellow
        let newColor: UIColor = isActive ? .white : .systemYellow
        filterButton.tintColor = newColor
        tbFilterBtn.tintColor  = newColor
    }

    @objc private func toggleAspect() {
        // Placeholder for future aspect ratio switching
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(audioManager: audioManager), animated: true)
    }

    @objc private func toggleManualControls() {
        UIView.animate(withDuration: 0.25) {
            self.manualControls.isHidden.toggle()
        }
        tbEVBtn.tintColor = manualControls.isHidden ? .white : .systemYellow
    }

    // MARK: Tap to Focus

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point      = gesture.location(in: previewContainer)
        let normalised = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        setFocusPoint(normalised)
        FocusReticleView().show(at: point, in: previewContainer)
    }

    private func setFocusPoint(_ point: CGPoint) {
        guard let device = currentDevice else { return }
        configQueue.async {
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
    }

    // MARK: Status

    private func startStatusUpdates() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.connectionsLabel.text = "\(self.ndiStreamer.connectedReceiverCount)"
        }
    }

    private func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: UI Layout

    private func setupUI() {
        // Full-screen preview behind everything
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewContainer)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewContainer.layer.addSublayer(previewLayer)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        previewContainer.addGestureRecognizer(tap)

        // ── TOP BAR ──────────────────────────────────────────────────────────

        let topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        configureCircleButton(torchButton,    systemImage: "bolt.fill",       action: #selector(toggleTorch))
        configureCircleButton(filterButton,   systemImage: "camera.filters",  action: #selector(toggleFilter))
        configureCircleButton(settingsButton, systemImage: "gearshape.fill",  action: #selector(openSettings))
        torchButton.translatesAutoresizingMaskIntoConstraints   = false
        filterButton.translatesAutoresizingMaskIntoConstraints  = false
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(torchButton)
        topBar.addSubview(filterButton)
        topBar.addSubview(settingsButton)

        let sourceName = UserDefaults.standard.string(forKey: "sourceName") ?? UIDevice.current.name
        sourceButton.setTitle(sourceName, for: .normal)
        sourceButton.setImage(
            UIImage(systemName: "chevron.down",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)),
            for: .normal
        )
        sourceButton.semanticContentAttribute = .forceRightToLeft
        sourceButton.tintColor               = .white
        sourceButton.titleLabel?.font        = .systemFont(ofSize: 14, weight: .medium)
        sourceButton.backgroundColor         = UIColor(white: 0.15, alpha: 0.75)
        sourceButton.layer.cornerRadius      = 16
        sourceButton.clipsToBounds           = true
        sourceButton.contentEdgeInsets       = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 10)
        sourceButton.imageEdgeInsets         = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
        sourceButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(sourceButton)

        // ── CAMERA TOOLBAR ───────────────────────────────────────────────────

        toolbarView.backgroundColor     = UIColor(white: 0.1, alpha: 0.88)
        toolbarView.layer.cornerRadius  = 20
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbarView)

        let tbStack = UIStackView()
        tbStack.axis         = .horizontal
        tbStack.distribution = .fillEqually
        tbStack.alignment    = .center
        tbStack.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.addSubview(tbStack)

        configureToolbarButton(tbTorchBtn,  systemImage: "bolt.fill",      action: #selector(toggleTorch))
        configureToolbarButton(tbFilterBtn, systemImage: "camera.filters", action: #selector(toggleFilter))
        configureToolbarButton(tbMicBtn,    systemImage: "mic.slash",      action: #selector(toggleMic))
        configureToolbarButton(tbAspectBtn, systemImage: nil,              action: #selector(toggleAspect))
        tbAspectBtn.setTitle("4:3", for: .normal)
        tbAspectBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        configureToolbarButton(tbEVBtn,    systemImage: "plusminus",       action: #selector(toggleManualControls))
        configureToolbarButton(tbTimerBtn, systemImage: "timer",           action: nil)

        [tbTorchBtn, tbFilterBtn, tbMicBtn, tbAspectBtn, tbEVBtn, tbTimerBtn].forEach {
            tbStack.addArrangedSubview($0)
        }

        // ── BOTTOM CONTROLS ──────────────────────────────────────────────────

        let bottomView = UIView()
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomView)

        // Connections indicator (bottom-left)
        connectionsView.backgroundColor    = UIColor(white: 0.12, alpha: 0.88)
        connectionsView.layer.cornerRadius = 14
        connectionsView.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(connectionsView)

        let connIconCfg  = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let connIconView = UIImageView(image: UIImage(systemName: "dot.radiowaves.right", withConfiguration: connIconCfg))
        connIconView.tintColor    = UIColor.white.withAlphaComponent(0.65)
        connIconView.contentMode  = .scaleAspectFit
        connIconView.translatesAutoresizingMaskIntoConstraints = false
        connectionsView.addSubview(connIconView)

        connectionsLabel.text      = "0"
        connectionsLabel.textColor = .white
        connectionsLabel.font      = .monospacedDigitSystemFont(ofSize: 17, weight: .bold)
        connectionsLabel.textAlignment = .center
        connectionsLabel.translatesAutoresizingMaskIntoConstraints = false
        connectionsView.addSubview(connectionsLabel)

        // Stream button — large white circle (center)
        streamButton.backgroundColor      = .white
        streamButton.layer.cornerRadius   = 36
        streamButton.layer.borderWidth    = 3
        streamButton.layer.borderColor    = UIColor(white: 0.85, alpha: 1).cgColor
        streamButton.clipsToBounds        = true
        streamButton.addTarget(self, action: #selector(toggleStreaming), for: .touchUpInside)
        streamButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(streamButton)

        // Inner decorative ring
        let innerRing                     = UIView()
        innerRing.backgroundColor         = .clear
        innerRing.layer.cornerRadius      = 29
        innerRing.layer.borderWidth       = 1.5
        innerRing.layer.borderColor       = UIColor(white: 0.6, alpha: 0.4).cgColor
        innerRing.isUserInteractionEnabled = false
        innerRing.translatesAutoresizingMaskIntoConstraints = false
        streamButton.addSubview(innerRing)

        // Switch camera button (bottom-right)
        let switchCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        switchButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera.fill", withConfiguration: switchCfg), for: .normal)
        switchButton.tintColor        = .white
        switchButton.backgroundColor  = UIColor(white: 0.2, alpha: 0.8)
        switchButton.layer.cornerRadius = 24
        switchButton.clipsToBounds    = true
        switchButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        switchButton.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(switchButton)

        // ── MANUAL CONTROLS (above toolbar, hidden by default) ───────────────

        manualControls.delegate = self
        manualControls.isHidden = true
        manualControls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(manualControls)

        // ── CONSTRAINTS ───────────────────────────────────────────────────────

        NSLayoutConstraint.activate([
            // Preview — full screen
            previewContainer.topAnchor.constraint(equalTo: view.topAnchor),
            previewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Top bar
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            torchButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            torchButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            torchButton.widthAnchor.constraint(equalToConstant: 40),
            torchButton.heightAnchor.constraint(equalToConstant: 40),

            filterButton.leadingAnchor.constraint(equalTo: torchButton.trailingAnchor, constant: 8),
            filterButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            filterButton.widthAnchor.constraint(equalToConstant: 40),
            filterButton.heightAnchor.constraint(equalToConstant: 40),

            sourceButton.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            sourceButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            settingsButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            settingsButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 40),
            settingsButton.heightAnchor.constraint(equalToConstant: 40),

            // Toolbar
            toolbarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            toolbarView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            toolbarView.bottomAnchor.constraint(equalTo: bottomView.topAnchor, constant: -12),
            toolbarView.heightAnchor.constraint(equalToConstant: 60),

            tbStack.topAnchor.constraint(equalTo: toolbarView.topAnchor),
            tbStack.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor, constant: 8),
            tbStack.trailingAnchor.constraint(equalTo: toolbarView.trailingAnchor, constant: -8),
            tbStack.bottomAnchor.constraint(equalTo: toolbarView.bottomAnchor),

            // Bottom view
            bottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            bottomView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            bottomView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            bottomView.heightAnchor.constraint(equalToConstant: 80),

            // Connections view
            connectionsView.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor),
            connectionsView.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            connectionsView.widthAnchor.constraint(equalToConstant: 62),
            connectionsView.heightAnchor.constraint(equalToConstant: 62),

            connIconView.topAnchor.constraint(equalTo: connectionsView.topAnchor, constant: 10),
            connIconView.centerXAnchor.constraint(equalTo: connectionsView.centerXAnchor),
            connIconView.widthAnchor.constraint(equalToConstant: 22),
            connIconView.heightAnchor.constraint(equalToConstant: 18),

            connectionsLabel.topAnchor.constraint(equalTo: connIconView.bottomAnchor, constant: 4),
            connectionsLabel.centerXAnchor.constraint(equalTo: connectionsView.centerXAnchor),

            // Stream button
            streamButton.centerXAnchor.constraint(equalTo: bottomView.centerXAnchor),
            streamButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            streamButton.widthAnchor.constraint(equalToConstant: 72),
            streamButton.heightAnchor.constraint(equalToConstant: 72),

            innerRing.centerXAnchor.constraint(equalTo: streamButton.centerXAnchor),
            innerRing.centerYAnchor.constraint(equalTo: streamButton.centerYAnchor),
            innerRing.widthAnchor.constraint(equalToConstant: 58),
            innerRing.heightAnchor.constraint(equalToConstant: 58),

            // Switch camera
            switchButton.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor),
            switchButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor),
            switchButton.widthAnchor.constraint(equalToConstant: 48),
            switchButton.heightAnchor.constraint(equalToConstant: 48),

            // Manual controls
            manualControls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            manualControls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            manualControls.bottomAnchor.constraint(equalTo: toolbarView.topAnchor, constant: -12),
        ])
    }

    private func configureCircleButton(_ button: UIButton, systemImage: String, action: Selector) {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: systemImage, withConfiguration: config), for: .normal)
        button.tintColor        = .white
        button.backgroundColor  = UIColor(white: 0.2, alpha: 0.75)
        button.layer.cornerRadius = 20
        button.clipsToBounds    = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func configureToolbarButton(_ button: UIButton, systemImage: String?, action: Selector?) {
        if let name = systemImage {
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            button.setImage(UIImage(systemName: name, withConfiguration: config), for: .normal)
        }
        button.tintColor = .white
        if let action = action {
            button.addTarget(self, action: action, for: .touchUpInside)
        }
    }
}

// MARK: - AVCapture delegates

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
        } else if output === audioOutput, !micMuted {
            ndiStreamer.sendAudioFrame(sampleBuffer)
        }
    }
}

// MARK: - ManualControlsDelegate

extension CameraViewController: ManualControlsDelegate {

    func manualControls(_ view: ManualControlsView, didChangeExposure bias: Float) {
        guard let device = currentDevice else { return }
        let clamped = max(device.minExposureTargetBias, min(device.maxExposureTargetBias, bias))
        configQueue.async {
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(clamped)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func manualControls(_ view: ManualControlsView, didChangeISO iso: Float) {
        guard let device = currentDevice else { return }
        let clampedISO = max(device.activeFormat.minISO, min(device.activeFormat.maxISO, iso))
        let duration   = device.exposureDuration
        configQueue.async {
            do {
                try device.lockForConfiguration()
                device.setExposureModeCustom(duration: duration, iso: clampedISO)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func manualControls(_ view: ManualControlsView, didChangeShutter duration: CMTime) {
        guard let device = currentDevice else { return }
        let currentISO = max(device.activeFormat.minISO,
                             min(device.activeFormat.maxISO, device.iso))
        configQueue.async {
            do {
                try device.lockForConfiguration()
                device.setExposureModeCustom(duration: duration, iso: currentISO)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func manualControls(_ view: ManualControlsView, didChangeWhiteBalance temperature: Float) {
        guard let device = currentDevice, device.isWhiteBalanceModeSupported(.locked) else { return }
        let tAndT = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: temperature, tint: 0)
        var gains = device.deviceWhiteBalanceGains(for: tAndT)
        let max   = device.maxWhiteBalanceGain
        gains.redGain   = Swift.max(1, Swift.min(max, gains.redGain))
        gains.greenGain = Swift.max(1, Swift.min(max, gains.greenGain))
        gains.blueGain  = Swift.max(1, Swift.min(max, gains.blueGain))
        configQueue.async {
            do {
                try device.lockForConfiguration()
                device.setWhiteBalanceModeLocked(with: gains)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func manualControlsDidRequestFocusLock(_ view: ManualControlsView) {
        guard let device = currentDevice, device.isFocusModeSupported(.locked) else { return }
        configQueue.async {
            do {
                try device.lockForConfiguration()
                device.focusMode = .locked
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func manualControlsDidRequestAutoFocus(_ view: ManualControlsView) {
        guard let device = currentDevice, device.isFocusModeSupported(.continuousAutoFocus) else { return }
        configQueue.async {
            do {
                try device.lockForConfiguration()
                device.focusMode = .continuousAutoFocus
                device.unlockForConfiguration()
            } catch {}
        }
    }
}
