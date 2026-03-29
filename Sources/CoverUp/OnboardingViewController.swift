import AppKit

// MARK: - Notification

extension NSNotification.Name {
    /// Posted when the user taps Continue after all permissions are granted.
    static let onboardingDidComplete = NSNotification.Name("com.namuan.coverup.onboardingDidComplete")
}

// MARK: - OnboardingViewController

/// Full-window onboarding screen that guides the user through granting
/// Screen Recording and Accessibility permissions.
final class OnboardingViewController: NSViewController {

    private var rowViews: [PermissionRowView] = []
    private var continueButton: NSButton!
    private var pollTimer: Timer?

    // MARK: - View lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        refresh()
        // Re-check status every second so the UI updates when the user
        // returns from System Settings without needing to click anything.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - UI construction

    private func buildUI() {
        // App icon / logo placeholder
        let appIcon = NSImageView()
        appIcon.image = NSImage(systemSymbolName: "rectangle.badge.minus", accessibilityDescription: nil)
        appIcon.symbolConfiguration = .init(pointSize: 44, weight: .light)
        appIcon.contentTintColor = .controlAccentColor
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(appIcon)

        // Title
        let titleLabel = NSTextField(labelWithString: "Welcome to CoverUp")
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = NSTextField(wrappingLabelWithString:
            "CoverUp hides sensitive screen regions in real time.\nTwo permissions are needed before it can work.")
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Permission rows
        var rowConstraints: [NSLayoutConstraint] = []
        var previousBottomAnchor = subtitleLabel.bottomAnchor
        for permission in PermissionManager.Permission.allCases {
            let row = PermissionRowView(permission: permission)
            row.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(row)
            rowViews.append(row)
            rowConstraints += [
                row.topAnchor.constraint(equalTo: previousBottomAnchor, constant: 16),
                row.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
                row.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            ]
            previousBottomAnchor = row.bottomAnchor
        }

        // Divider
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(divider)

        // Continue button
        continueButton = NSButton(title: "Continue", target: self, action: #selector(continueTapped))
        continueButton.bezelStyle = .rounded
        continueButton.keyEquivalent = "\r"
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(continueButton)

        // Activate constraints
        NSLayoutConstraint.activate([
            appIcon.topAnchor.constraint(equalTo: view.topAnchor, constant: 32),
            appIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            appIcon.widthAnchor.constraint(equalToConstant: 52),
            appIcon.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.topAnchor.constraint(equalTo: appIcon.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            divider.topAnchor.constraint(equalTo: previousBottomAnchor, constant: 20),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            continueButton.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 14),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ] + rowConstraints)
    }

    // MARK: - State refresh

    private func refresh() {
        rowViews.forEach { $0.refresh() }
        let allGranted = PermissionManager.allGranted
        continueButton.isEnabled = allGranted
        continueButton.title = allGranted ? "Continue" : "Waiting for Permissions…"
    }

    // MARK: - Actions

    @objc private func continueTapped() {
        pollTimer?.invalidate()
        pollTimer = nil
        view.window?.close()
        NotificationCenter.default.post(name: .onboardingDidComplete, object: nil)
    }
}

// MARK: - PermissionRowView

private final class PermissionRowView: NSView {

    private let permission: PermissionManager.Permission
    private var statusLabel: NSTextField!
    private var actionButton: NSButton!

    init(permission: PermissionManager.Permission) {
        self.permission = permission
        super.init(frame: .zero)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1

        // Icon
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: permission.symbolName, accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: 26, weight: .regular)
        icon.contentTintColor = .controlAccentColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)

        // Title
        let titleLabel = NSTextField(labelWithString: permission.title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Detail
        let detailLabel = NSTextField(wrappingLabelWithString: permission.detail)
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(detailLabel)

        // Status badge
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)

        // Action button
        actionButton = NSButton(title: "Open Settings", target: self, action: #selector(openSettings))
        actionButton.bezelStyle = .rounded
        actionButton.controlSize = .small
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(actionButton)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 36),
            icon.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -8),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -12),
            detailLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            statusLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            actionButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 76),
        ])
    }

    func refresh() {
        let granted = permission.isGranted
        if granted {
            statusLabel.stringValue = "✓ Granted"
            statusLabel.textColor = .systemGreen
            actionButton.title = "Granted"
            actionButton.isEnabled = false
            layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.35).cgColor
            layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.06).cgColor
        } else {
            statusLabel.stringValue = "Required"
            statusLabel.textColor = .systemOrange
            actionButton.title = "Open Settings"
            actionButton.isEnabled = true
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        }
    }

    @objc private func openSettings() {
        permission.requestAccess()
        NSWorkspace.shared.open(permission.settingsURL)
    }
}
