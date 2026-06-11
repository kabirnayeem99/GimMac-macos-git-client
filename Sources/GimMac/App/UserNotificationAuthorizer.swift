import Foundation
@preconcurrency import UserNotifications

/// Wraps `UNUserNotificationCenter` to expose notification permission state and
/// requests. Native equivalent of GitHub Desktop's notification-permission
/// inspection in its Notifications preferences panel.
///
/// `UNUserNotificationCenter` is not `Sendable`, so the center is resolved via
/// `.current()` inside each call rather than stored.
final class UserNotificationAuthorizer: NotificationAuthorizing, Sendable {
    func authorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return Self.map(settings.authorizationStatus)
    }

    @discardableResult
    func requestAuthorization() async -> NotificationAuthorizationStatus {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        return await authorizationStatus()
    }

    private static func map(_ status: UNAuthorizationStatus) -> NotificationAuthorizationStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .authorized
        @unknown default: return .unknown
        }
    }
}
