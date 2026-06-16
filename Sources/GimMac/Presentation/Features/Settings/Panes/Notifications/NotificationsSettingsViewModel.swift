import Foundation
import Observation

/// Drives the Notifications pane of Settings: the enable toggle plus the live
/// permission state used to surface a "grant permission" / "open System
/// Settings" hint. Native equivalent of GitHub Desktop's `Notifications`
/// preferences panel (`ui/preferences/notifications.tsx`).
@MainActor
@Observable
final class NotificationsSettingsViewModel {
    var notificationsEnabled: Bool {
        didSet { store.notificationsEnabled = notificationsEnabled }
    }
    private(set) var permissionStatus: NotificationAuthorizationStatus = .unknown

    private let store: any AppSettingsStoring
    private let authorizer: any NotificationAuthorizing

    init(store: any AppSettingsStoring, authorizer: any NotificationAuthorizing) {
        self.store = store
        self.authorizer = authorizer
        notificationsEnabled = store.notificationsEnabled
    }

    func refreshPermissionStatus() async {
        permissionStatus = await authorizer.authorizationStatus()
    }

    func requestPermission() async {
        permissionStatus = await authorizer.requestAuthorization()
    }
}
