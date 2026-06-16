import AppKit
import SwiftUI

/// Hosts the SwiftUI `CreateRepositorySheet` in an `NSViewController` so it can
/// be presented as a sheet from the AppKit menu. Stays free of services — the
/// host wires the sheet's closures to the view model. Mirrors
/// `CloneRepositoryWindowController` in shape.
@MainActor
final class CreateRepositoryWindowController {
    typealias LoadTemplates = () async -> ([String], [LicenseTemplate])
    typealias Completion = (_ options: RepositoryCreationOptions, _ destination: URL) -> Void

    let viewController: NSViewController

    init(
        loadTemplates: @escaping LoadTemplates,
        onCreate: @escaping Completion
    ) {
        // `dismiss` is resolved against the hosting controller once it exists,
        // so capture it weakly through a holder.
        let holder = DismissHolder()
        let sheet = CreateRepositorySheet(
            loadTemplates: loadTemplates,
            onCreate: { options, destination in
                onCreate(options, destination)
                holder.dismiss?()
            },
            onCancel: { holder.dismiss?() }
        )
        let hosting = NSHostingController(rootView: sheet)
        holder.dismiss = { [weak hosting] in hosting?.dismiss(nil) }
        self.viewController = hosting
    }
}

/// Lets the SwiftUI closures dismiss the hosting controller without the view
/// holding an AppKit reference.
@MainActor
private final class DismissHolder {
    var dismiss: (() -> Void)?
}
