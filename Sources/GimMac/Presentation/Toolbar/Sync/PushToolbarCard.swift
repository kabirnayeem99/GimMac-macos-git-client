import SwiftUI

struct PushToolbarCard: View {
    let label: String
    let subtitle: String
    let badge: String?
    let lastFetched: Date?
    var isLoading: Bool = false
    var outcome: OpOutcome = .none

    @State private var now = Date()
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var fetchedDescription: String {
        guard let date = lastFetched else { return subtitle }
        return "Last fetched " + AppFormatters.relativeDate.localizedString(for: date, relativeTo: now)
    }

    private var symbolName: String {
        switch outcome {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.triangle.fill"
        case .none:
            return "arrow.triangle.2.circlepath"
        }
    }

    private var symbolColor: Color {
        switch outcome {
        case .success:
            return .green
        case .failure:
            return .red
        case .none:
            return .primary
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(symbolColor)
                .frame(width: 16, height: 16)
                .symbolReplacement(reduceMotion: reduceMotion)
                .symbolEffect(
                    .pulse,
                    options: .nonRepeating,
                    isActive: isLoading && !reduceMotion
                )
                .symbolEffect(
                    .pulse,
                    options: .nonRepeating,
                    isActive: outcome == .failure && !reduceMotion
                )
                .motion(Motion.feedback, reduceMotion: reduceMotion, value: outcome)

            if let badge, !isLoading {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .motion(Motion.feedback, reduceMotion: reduceMotion, value: badge)
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
        .scaleEffect(reduceMotion || !isHovered ? 1 : 1.03)
        .opacity(isHovered ? 0.92 : 1)
        .motion(Motion.snappy, reduceMotion: reduceMotion, value: isHovered)
        .help("\(label) — \(fetchedDescription)")
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
        .onHover { isHovered = $0 }
        .onReceive(ticker) { date in
            now = date
        }
    }
}
