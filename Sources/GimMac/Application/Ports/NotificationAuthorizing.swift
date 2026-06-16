import Foundation

/// Reads and requests the user-notification permission. The concrete
/// implementation wraps `UNUserNotificationCenter` in Infrastructure/Platform.
protocol NotificationAuthorizing: Sendable {
    func authorizationStatus() async -> NotificationAuthorizationStatus
    @discardableResult
    func requestAuthorization() async -> NotificationAuthorizationStatus
}
