import SwiftUI

struct CommitHistorySidebar: View {
    @Binding var selectedTab: Int

    private let commits = [
        ("Update MainSplitViewContro...", "Naimul Kabir • 13 minutes ago"),
        ("Merge branch 'master' of https://git...", "Naimul Kabir • 17 minutes ago"),
        ("refactor(app): consolidate AppDele...", "Naimul Kabir • 1 hour ago"),
        ("feat(app): implement some menu it...", "Naimul Kabir • 1 hour ago"),
        ("feat(git): implement phase 2 git clie...", "Naimul Kabir • 2 hours ago"),
        ("feat(appkit): implement phase 1 rep...", "Naimul Kabir • 3 hours ago"),
        ("chore(repo): complete phase 0 arch...", "Naimul Kabir • 4 hours ago"),
        ("chore(repo): bootstrap GimMac ma...", "Naimul Kabir • 5 hours ago")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Changes").tag(0)
                Text("History").tag(1)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .padding(10)

            Button {
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 12))

                    Text("No Branches to Compare")
                        .font(.system(size: 12))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            List(commits.indices, id: \.self) { index in
                CommitRow(
                    title: commits[index].0,
                    subtitle: commits[index].1,
                    selected: index == 0
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(.thinMaterial)
    }
}
