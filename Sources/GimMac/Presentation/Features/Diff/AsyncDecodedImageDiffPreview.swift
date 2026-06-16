import AppKit
import SwiftUI

struct AsyncDecodedImageDiffPreview: View {
    let content: ImageDiffContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: NSImage?
    @State private var failedToDecode = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 320, maxHeight: 320)
                    .asyncDecodeFade(reduceMotion: reduceMotion, isReady: true)
            } else if failedToDecode {
                Text("Cannot preview")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 120, height: 120)
            } else {
                LoadingPlaceholder(title: "Loading preview…", minHeight: 120)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: content.base64Contents) {
            image = nil
            failedToDecode = false
            let decoded = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                guard let bytes = Data(base64Encoded: content.base64Contents) else { return nil }
                return NSImage(data: bytes)
            }.value
            guard !Task.isCancelled else { return }
            image = decoded
            failedToDecode = decoded == nil
        }
    }
}
