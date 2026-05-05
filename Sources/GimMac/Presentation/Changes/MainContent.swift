import SwiftUI

struct MainContent: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderSection()

                VStack(spacing: 0) {
                    SuggestionCard(
                        title: "Push commits to the origin remote",
                        subtitle: "You have 1 local commit waiting to be pushed.",
                        hint: "Available from the toolbar or with ⌘P.",
                        button: "Push origin",
                        highlighted: true
                    )

                    SuggestionCard(
                        title: "Open the repository in your editor",
                        subtitle: "Select your preferred editor in Settings.",
                        hint: "Repository menu or ⌘⇧A.",
                        button: "Open in VS Code"
                    )

                    SuggestionCard(
                        title: "View repository files in Finder",
                        subtitle: nil,
                        hint: "Repository menu or ⌘⇧F.",
                        button: "Show in Finder"
                    )

                    SuggestionCard(
                        title: "Open the repository page in your browser",
                        subtitle: nil,
                        hint: "Repository menu or ⌘⇧G.",
                        button: "View Remote"
                    )
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 72)
            .padding(.top, 56)
            .padding(.bottom, 32)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}
