import SwiftUI

struct PushToolbarCard: View {
    let label: String
    let subtitle: String
    let badge: String?
    let lastFetched: Date?
    var isLoading: Bool = false

    @State private var now = Date()

    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var fetchedDescription: String {
        guard let date = lastFetched else { return subtitle }
        return "Last fetched " + AppFormatters.relativeDate.localizedString(for: date, relativeTo: now)
    }

    var body: some View {
        HStack(spacing: 5) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)
            }

            if let badge, !isLoading {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(height: 28)
        .padding(.horizontal, 8)
        .toolbarItemStyle()
        .help("\(label) — \(fetchedDescription)")
        .onReceive(ticker) { date in
            now = date
        }
    }
}
