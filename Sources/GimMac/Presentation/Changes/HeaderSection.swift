import SwiftUI

struct HeaderSection: View {
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("No local changes")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("There are no uncommitted changes in this repository. Choose an action below to continue.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
    }
}
