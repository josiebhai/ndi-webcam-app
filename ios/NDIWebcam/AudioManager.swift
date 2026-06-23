import AVFoundation
import Combine

final class AudioManager: ObservableObject {

    struct AudioDevice: Identifiable, Equatable {
        let id: String          // UID
        let name: String
        let portType: AVAudioSession.Port
    }

    @Published private(set) var availableInputs: [AudioDevice] = []
    @Published private(set) var selectedInput: AudioDevice?

    private var routeChangeObserver: NSObjectProtocol?

    init() {
        refresh()
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let obs = routeChangeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // Reload list of available inputs from the current audio session.
    func refresh() {
        let session = AVAudioSession.sharedInstance()
        let ports = session.availableInputs ?? []
        availableInputs = ports.map { port in
            AudioDevice(id: port.uid, name: port.portName, portType: port.portType)
        }
        // Preserve selection if the previously selected device is still present.
        if let current = selectedInput, !availableInputs.contains(current) {
            selectedInput = availableInputs.first
        }
        if selectedInput == nil {
            selectedInput = availableInputs.first
        }
    }

    // Switch the active audio input. AVAudioSession will reroute immediately.
    func select(_ device: AudioDevice) {
        let session = AVAudioSession.sharedInstance()
        guard let port = session.availableInputs?.first(where: { $0.uid == device.id }) else { return }
        do {
            try session.setPreferredInput(port)
            selectedInput = device
        } catch {
            print("Failed to set preferred input: \(error)")
        }
    }
}
