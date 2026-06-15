import AppKit
import Observation

/// Notifications pane: the enable toggle plus a live permission hint that lets
/// the user grant permission or jump to System Settings. Native equivalent of
/// GitHub Desktop's `Notifications` preferences panel.
@MainActor
final class NotificationsSettingsPaneController: SettingsPaneViewController {
    private let viewModel: NotificationsSettingsViewModel
    private weak var hintLabel: NSTextField?
    private weak var grantButton: NSButton?
    private weak var openSettingsButton: NSButton?
    private var isVisible = false

    private static let notificationSettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")

    init(viewModel: NotificationsSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func buildContent() {
        addHeader("Notifications")

        let hint = NSTextField(wrappingLabelWithString: "")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 12)
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.widthAnchor.constraint(equalToConstant: 460).isActive = true
        hintLabel = hint

        let grant = makeButton("Grant Permission…") { [weak self] in
            guard let self else { return }
            Task { await self.viewModel.requestPermission() }
        }
        grant.isHidden = true
        grantButton = grant

        let openSettings = makeButton("Open Notification Settings…") { [weak self] in
            self?.openSystemNotificationSettings()
        }
        openSettings.isHidden = true
        openSettingsButton = openSettings

        addSection(nil, views: [
            makeCheckbox("Enable notifications", isOn: viewModel.notificationsEnabled) { [weak self] in
                self?.viewModel.notificationsEnabled = $0
                self?.refreshHint()
            },
            makeNote("Show notifications when high-signal events take place in the current repository."),
            hint,
            grant,
            openSettings
        ])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        isVisible = true
        trackState()
        Task { [weak self] in
            await self?.viewModel.refreshPermissionStatus()
            self?.refreshHint()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        isVisible = false
    }

    private func trackState() {
        guard isVisible else { return }
        withObservationTracking {
            refreshHint()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.trackState() }
        }
    }

    /// Mirrors GitHub Desktop's grant / denied / configure states.
    private func refreshHint() {
        guard viewModel.notificationsEnabled else {
            setHintGroupVisible(false)
            return
        }

        switch viewModel.permissionStatus {
        case .notDetermined:
            hintLabel?.stringValue = "Grant permission to display notifications from GimMac."
            setHintGroupVisible(true)
            fadeButton(grantButton, visible: true)
            fadeButton(openSettingsButton, visible: false)
        case .denied:
            hintLabel?.stringValue = "GimMac is not allowed to display notifications. Enable them in System Settings."
            setHintGroupVisible(true)
            fadeButton(grantButton, visible: false)
            fadeButton(openSettingsButton, visible: true)
        case .authorized, .provisional:
            hintLabel?.stringValue = "Notifications are enabled for GimMac."
            setHintGroupVisible(true)
            fadeButton(grantButton, visible: false)
            fadeButton(openSettingsButton, visible: false)
        case .unknown:
            setHintGroupVisible(false)
        }
    }

    private func setHintGroupVisible(_ visible: Bool) {
        hintLabel?.fadeBanner(visible: visible)
        if !visible {
            fadeButton(grantButton, visible: false)
            fadeButton(openSettingsButton, visible: false)
        }
    }

    private func fadeButton(_ button: NSButton?, visible: Bool) {
        guard let button else { return }
        button.fadeBanner(visible: visible)
    }

    private func openSystemNotificationSettings() {
        guard let url = Self.notificationSettingsURL else { return }
        NSWorkspace.shared.open(url)
    }
}
