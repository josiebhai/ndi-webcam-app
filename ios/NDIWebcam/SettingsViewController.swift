import UIKit
import AVFoundation
import Combine

final class SettingsViewController: UITableViewController {

    private let audioManager: AudioManager
    private var cancellables = Set<AnyCancellable>()

    // Settings keys
    private enum Key {
        static let sourceName  = "sourceName"
        static let resolution  = "resolution"
        static let fps         = "fps"
        static let ndiMode     = "ndiMode"     // "HX" or "Full"
        static let discoveryServer = "discoveryServer"
    }

    private enum Section: Int, CaseIterable {
        case source, video, audio, network
        var title: String {
            switch self {
            case .source:  return "Source"
            case .video:   return "Video"
            case .audio:   return "Audio"
            case .network: return "Network"
            }
        }
    }

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(TextFieldCell.self, forCellReuseIdentifier: "TextFieldCell")
        tableView.register(SegmentCell.self, forCellReuseIdentifier: "SegmentCell")

        audioManager.$availableInputs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.tableView.reloadSections(IndexSet(integer: Section.audio.rawValue), with: .automatic) }
            .store(in: &cancellables)
    }

    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .source:  return 1            // source name
        case .video:   return 3            // resolution, fps, ndi mode
        case .audio:   return audioManager.availableInputs.count
        case .network: return 1            // discovery server
        case .none:    return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .source:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath) as! TextFieldCell
            cell.configure(
                placeholder: UIDevice.current.name,
                value: UserDefaults.standard.string(forKey: Key.sourceName) ?? "",
                onChange: { UserDefaults.standard.set($0, forKey: Key.sourceName) }
            )
            return cell

        case .video:
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentCell", for: indexPath) as! SegmentCell
                cell.configure(
                    title: "Resolution",
                    items: ["720p", "1080p", "4K"],
                    selected: UserDefaults.standard.integer(forKey: Key.resolution),
                    onChange: { UserDefaults.standard.set($0, forKey: Key.resolution) }
                )
                return cell
            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentCell", for: indexPath) as! SegmentCell
                cell.configure(
                    title: "Frame Rate",
                    items: ["24", "30", "60"],
                    selected: UserDefaults.standard.integer(forKey: Key.fps),
                    onChange: { UserDefaults.standard.set($0, forKey: Key.fps) }
                )
                return cell
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentCell", for: indexPath) as! SegmentCell
                cell.configure(
                    title: "NDI Mode",
                    items: ["NDI|HX", "Full NDI"],
                    selected: UserDefaults.standard.integer(forKey: Key.ndiMode),
                    onChange: { UserDefaults.standard.set($0, forKey: Key.ndiMode) }
                )
                return cell
            }

        case .audio:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            let device = audioManager.availableInputs[indexPath.row]
            cell.textLabel?.text = device.name
            cell.accessoryType = device == audioManager.selectedInput ? .checkmark : .none
            return cell

        case .network:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath) as! TextFieldCell
            cell.configure(
                placeholder: "NDI Discovery Server IP (optional)",
                value: UserDefaults.standard.string(forKey: Key.discoveryServer) ?? "",
                onChange: { UserDefaults.standard.set($0, forKey: Key.discoveryServer) }
            )
            return cell

        case .none:
            return UITableViewCell()
        }
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .audio else { return }
        let device = audioManager.availableInputs[indexPath.row]
        audioManager.select(device)
        tableView.reloadSections(IndexSet(integer: Section.audio.rawValue), with: .none)
    }
}

// MARK: - Custom Cells

final class TextFieldCell: UITableViewCell {
    private let textField = UITextField()
    private var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.clearButtonMode = .whileEditing
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        contentView.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(placeholder: String, value: String, onChange: @escaping (String) -> Void) {
        textField.placeholder = placeholder
        textField.text = value
        self.onChange = onChange
    }

    @objc private func textChanged() { onChange?(textField.text ?? "") }
}

final class SegmentCell: UITableViewCell {
    private let label    = UILabel()
    private let segment  = UISegmentedControl()
    private var onChange: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        let stack = UIStackView(arrangedSubviews: [label, segment])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
        segment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, items: [String], selected: Int, onChange: @escaping (Int) -> Void) {
        label.text = title
        segment.removeAllSegments()
        items.enumerated().forEach { i, item in segment.insertSegment(withTitle: item, at: i, animated: false) }
        segment.selectedSegmentIndex = selected
        self.onChange = onChange
    }

    @objc private func segmentChanged() { onChange?(segment.selectedSegmentIndex) }
}
