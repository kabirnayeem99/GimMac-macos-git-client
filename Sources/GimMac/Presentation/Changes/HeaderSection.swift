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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)

                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
    }
}
