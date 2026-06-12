import Foundation

/// Shared formatters to avoid expensive re-allocation in UI components and view models.
enum AppFormatters {
    /// Formatter for "Last fetched 2 minutes ago", etc.
    static let relativeDate: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
