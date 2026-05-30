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
        return "Last fetched " + RelativeDateTimeFormatter().localizedString(for: date, relativeTo: now)
    }

    var body: some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .frame(width: 17, height: 17)
            } else {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))

                Text(fetchedDescription)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let badge, !isLoading {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onReceive(ticker) { date in
            now = date
        }
    }
}
