import Foundation

/// Notification permission state, mapped from `UNAuthorizationStatus`. Native
/// equivalent of the `default` / `denied` / `granted` states GitHub Desktop
/// inspects in its Notifications preferences panel.
enum NotificationAuthorizationStatus: Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case unknown
}
