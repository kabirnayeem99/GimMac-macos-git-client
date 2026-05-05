import SwiftUI

struct HeaderSection: View {
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Working Tree")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)

                Text("No local changes")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("There are no uncommitted changes in this repository. Choose an action below to continue.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
    }
}
