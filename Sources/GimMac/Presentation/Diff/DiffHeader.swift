import SwiftUI

struct DiffHeader: View {
    let filePath: String
    let addedCount: Int
    let removedCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)

            Text(filePath.isEmpty ? "No file selected" : filePath)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 6) {
                Text("+\(addedCount)")
                    .foregroundStyle(.green)

                Text("-\(removedCount)")
                    .foregroundStyle(.red)
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))

            Button {
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)

            Button {
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
