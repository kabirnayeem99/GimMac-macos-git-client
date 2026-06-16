import SwiftUI

struct FilterChips<Option: Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    let onRemove: (Option) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button {
                        onRemove(option)
                    } label: {
                        Label(title(option), systemImage: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .accessibilityLabel("Remove \(title(option)) filter")
                }
            }
            .padding(.horizontal, 12)
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 8)
    }
}
