import SwiftUI

struct Sidebar: View {
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Changes").tag(0)
                Text("History").tag(1)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                Button {
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                TextField("Filter", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text("0 changed files")
                    .font(.system(size: 12, weight: .medium))

                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 30)

            Divider()

            Spacer()

            CommitBox()
        }
        .background(.thinMaterial)
    }
}
