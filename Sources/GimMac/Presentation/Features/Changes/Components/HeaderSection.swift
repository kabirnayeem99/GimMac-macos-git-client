import SwiftUI

struct HeaderSection: View {
    let title: String
    let subtitle: String
    let icon: String

    init(
        title: String = "No local changes",
        subtitle: String = "There are no uncommitted changes in this repository. Choose an action below to continue.",
        icon: String = "tray"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Working Tree")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)

                Text(title)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Image(systemName: icon)
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
                .accessibilityHidden(true)
        }
    }
}
