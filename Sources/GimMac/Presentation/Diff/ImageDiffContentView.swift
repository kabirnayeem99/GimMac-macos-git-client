import SwiftUI

/// Renders an image diff as before/after previews.
struct ImageDiffContentView: View {
    let data: ImageDiffData

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 24) {
                side("Previous", data.previous)
                side("Current", data.current)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func side(_ title: String, _ content: ImageDiffContent?) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            if let content {
                AsyncDecodedImageDiffPreview(content: content)
                    .frame(width: 320, height: 320)
                    .border(Color(nsColor: .separatorColor))
            } else {
                Text(content == nil ? "—" : "Cannot preview")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 120, height: 120)
            }
        }
    }
}
