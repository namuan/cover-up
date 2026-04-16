import AppKit
import Combine

/// Shows a list of regions with toggle checkbox and delete button.
final class RegionListController: NSViewController {

    private let manager: MaskRegionManager
    private var cancellables = Set<AnyCancellable>()

    private var stackView: NSStackView!

    init(manager: MaskRegionManager) {
        self.manager = manager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 400))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stackView.frame = scroll.contentView.bounds
        stackView.autoresizingMask = [.width]
        scroll.documentView = stackView
        view = scroll
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        manager.regionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reload() }
                .store(in: &cancellables)
        reload()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        resizeDocumentView()
    }

    private func reload() {
        for arrangedSubview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        if manager.regions.isEmpty {
            stackView.addArrangedSubview(makeEmptyStateRow())
        } else {
            for region in manager.regions {
                let row = makeRow(for: region)
                stackView.addArrangedSubview(row)
            }
        }

        resizeDocumentView()
    }

    private func makeRow(for region: MaskRegion) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8

        let check = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        check.state = region.isActive ? .on : .off
        check.action = #selector(toggleRegion(_:))
        check.identifier = NSUserInterfaceItemIdentifier(region.id)
        check.target = self

        let title = region.targetWindowTitle ?? "Static"
        let label = NSTextField(labelWithString: "\(region.id.prefix(8))… \(title)")
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.lineBreakMode = .byTruncatingTail

        let del = NSButton(title: "✕", target: self, action: #selector(deleteRegion(_:)))
        del.identifier = NSUserInterfaceItemIdentifier(region.id)
        del.bezelStyle = .inline

        row.addArrangedSubview(check)
        row.addArrangedSubview(label)
        row.addArrangedSubview(del)
        return row
    }

    private func makeEmptyStateRow() -> NSView {
        let label = NSTextField(labelWithString: "No regions yet. Choose Add Static Region from the menu.")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private func resizeDocumentView() {
        guard let scrollView = view as? NSScrollView else { return }
        let contentSize = scrollView.contentSize
        let fittingSize = stackView.fittingSize
        let newFrame = NSRect(
            x: 0,
            y: 0,
            width: max(contentSize.width, 320),
            height: max(contentSize.height, fittingSize.height)
        )
        guard stackView.frame != newFrame else { return }
        stackView.frame = newFrame
    }

    @objc private func toggleRegion(_ sender: NSButton) {
        manager.toggleRegion(id: sender.identifier!.rawValue)
    }

    @objc private func deleteRegion(_ sender: NSButton) {
        manager.removeRegion(id: sender.identifier!.rawValue)
    }
}
