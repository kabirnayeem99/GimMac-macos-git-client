import AppKit

/// Builds the application main menu.
///
/// Routing model: most real items use `target = nil` and a typed `#selector`,
/// so the action travels the responder chain. App-level commands (About,
/// Settings, Quit, Hide, etc.) are bound to a concrete target (AppDelegate or
/// NSApp). Git-repository actions are handled by `MainSplitViewController`,
/// which is in the responder chain and owns the repository VM.
///
/// Dynamic labels and enabled/disabled state are driven by
/// `NSMenuValidation.validateMenuItem(_:)` on the responder that owns the
/// action — see `MainSplitViewController`.
@MainActor
enum MainMenuFactory {

    // MARK: - Action selectors (responder-chain routed)
    //
    // All git/repository actions use `target = nil`; the responder chain finds
    // the implementing object (MainSplitViewController for repo work, NSApp /
    // NSTextView / etc. for native roles).

    // File
    static let newRepositoryAction = #selector(MainSplitViewController.menuNewRepository(_:))
    static let addLocalRepositoryAction = #selector(MainSplitViewController.menuAddLocalRepository(_:))
    static let cloneRepositoryAction = #selector(MainSplitViewController.menuCloneRepository(_:))

    // Repository
    static let pushAction = #selector(MainSplitViewController.menuPush(_:))
    static let pullAction = #selector(MainSplitViewController.menuPull(_:))
    static let fetchAction = #selector(MainSplitViewController.menuFetch(_:))
    static let showInFinderAction = #selector(MainSplitViewController.menuShowInFinder(_:))
    static let removeRepositoryAction = #selector(MainSplitViewController.menuRemoveRepository(_:))
    static let openInShellAction = #selector(MainSplitViewController.menuOpenInShell(_:))

    // Branch
    static let newBranchAction = #selector(MainSplitViewController.menuNewBranch(_:))
    static let renameBranchAction = #selector(MainSplitViewController.menuRenameBranch(_:))
    static let deleteBranchAction = #selector(MainSplitViewController.menuDeleteBranch(_:))
    static let compareToBranchAction = #selector(MainSplitViewController.menuCompareToBranch(_:))
    static let updateFromDefaultAction = #selector(MainSplitViewController.menuUpdateFromDefault(_:))
    static let stashAllChangesAction = #selector(MainSplitViewController.menuStashAllChanges(_:))
    static let discardAllChangesAction = #selector(MainSplitViewController.menuDiscardAllChanges(_:))
    static let mergeIntoCurrentAction = #selector(MainSplitViewController.menuMergeIntoCurrent(_:))
    static let squashAndMergeAction = #selector(MainSplitViewController.menuSquashAndMerge(_:))
    static let rebaseAction = #selector(MainSplitViewController.menuRebase(_:))

    // View
    static let showChangesAction = #selector(MainSplitViewController.menuShowChanges(_:))
    static let showHistoryAction = #selector(MainSplitViewController.menuShowHistory(_:))

    static func buildMainMenu(
        actionTarget: AnyObject,
        placeholderAction: Selector,
        aboutAction: Selector,
        settingsAction: Selector,
        openInEditorAction: Selector,
        repositorySettingsAction: Selector
    ) -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem(title: "GimMac", action: nil, keyEquivalent: "")
        appMenuItem.submenu = buildAppMenu(
            actionTarget: actionTarget,
            aboutAction: aboutAction,
            settingsAction: settingsAction
        )
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = buildFileMenu(
            actionTarget: actionTarget,
            placeholderAction: placeholderAction,
            openInEditorAction: openInEditorAction,
            repositorySettingsAction: repositorySettingsAction
        )
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = buildEditMenu()
        mainMenu.addItem(editMenuItem)

        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        viewMenuItem.submenu = buildViewMenu()
        mainMenu.addItem(viewMenuItem)

        let repositoryMenuItem = NSMenuItem(title: "Repository", action: nil, keyEquivalent: "")
        repositoryMenuItem.submenu = buildRepositoryMenu(openInEditorAction: openInEditorAction)
        mainMenu.addItem(repositoryMenuItem)

        let branchMenuItem = NSMenuItem(title: "Branch", action: nil, keyEquivalent: "")
        branchMenuItem.submenu = buildBranchMenu()
        mainMenu.addItem(branchMenuItem)

        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowMenuItem.submenu = buildWindowMenu()
        mainMenu.addItem(windowMenuItem)

        let helpMenuItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        helpMenuItem.submenu = buildHelpMenu(actionTarget: actionTarget, placeholderAction: placeholderAction)
        mainMenu.addItem(helpMenuItem)

        return mainMenu
    }

    private static func item(
        _ title: String,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [.command],
        target: AnyObject?,
        action: Selector?
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = target
        menuItem.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
        return menuItem
    }

    /// Responder-chain item: leaves `target = nil` so AppKit routes the
    /// selector up the chain to the first responder that implements it.
    private static func responderItem(
        _ title: String,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [.command],
        action: Selector
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = nil
        menuItem.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
        return menuItem
    }

    private static func buildAppMenu(
        actionTarget: AnyObject,
        aboutAction: Selector,
        settingsAction: Selector
    ) -> NSMenu {
        let menu = NSMenu(title: "GimMac")
        menu.addItem(item("About GimMac", target: actionTarget, action: aboutAction))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", key: ",", target: actionTarget, action: settingsAction))

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        menu.addItem(servicesItem)

        menu.addItem(.separator())
        menu.addItem(item("Hide GimMac", key: "h", target: NSApp, action: #selector(NSApplication.hide(_:))))
        menu.addItem(item("Hide Others", key: "h", modifiers: [.command, .option], target: NSApp, action: #selector(NSApplication.hideOtherApplications(_:))))
        menu.addItem(item("Show All", target: NSApp, action: #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Quit GimMac", key: "q", target: NSApp, action: #selector(NSApplication.terminate(_:))))
        return menu
    }

    private static func buildFileMenu(
        actionTarget: AnyObject,
        placeholderAction: Selector,
        openInEditorAction: Selector,
        repositorySettingsAction: Selector
    ) -> NSMenu {
        let menu = NSMenu(title: "File")

        // Repository creation flows — routed via the responder chain to
        // MainSplitViewController, which owns the VM + sheet presentation.
        menu.addItem(responderItem("New Repository…", key: "n", action: newRepositoryAction))
        menu.addItem(responderItem("Add Local Repository…", key: "o", action: addLocalRepositoryAction))
        menu.addItem(responderItem("Clone Repository…", key: "O", modifiers: [.command, .shift], action: cloneRepositoryAction))
        menu.addItem(.separator())
        menu.addItem(item("Open in External Editor", key: "e", modifiers: [.command, .shift], target: actionTarget, action: openInEditorAction))
        menu.addItem(.separator())
        menu.addItem(item("Repository Settings…", key: "i", modifiers: [.command, .shift], target: actionTarget, action: repositorySettingsAction))

        return menu
    }

    /// Edit menu uses native NSResponder selectors so AppKit auto-routes them
    /// to the first responder (text fields, text views).
    private static func buildEditMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(responderItem("Undo", key: "z", action: Selector(("undo:"))))
        menu.addItem(responderItem("Redo", key: "Z", action: Selector(("redo:"))))
        menu.addItem(.separator())
        menu.addItem(responderItem("Cut", key: "x", action: #selector(NSText.cut(_:))))
        menu.addItem(responderItem("Copy", key: "c", action: #selector(NSText.copy(_:))))
        menu.addItem(responderItem("Paste", key: "v", action: #selector(NSText.paste(_:))))
        menu.addItem(responderItem("Paste and Match Style", key: "V", modifiers: [.command, .shift, .option], action: #selector(NSTextView.pasteAsPlainText(_:))))
        menu.addItem(responderItem("Delete", action: #selector(NSText.delete(_:))))
        menu.addItem(responderItem("Select All", key: "a", action: #selector(NSText.selectAll(_:))))
        menu.addItem(.separator())
        menu.addItem(responderItem("Find", key: "f", action: #selector(NSResponder.performTextFinderAction(_:))))
        return menu
    }

    private static func buildViewMenu() -> NSMenu {
        let menu = NSMenu(title: "View")
        menu.addItem(responderItem("Show Changes", key: "1", action: showChangesAction))
        menu.addItem(responderItem("Show History", key: "2", action: showHistoryAction))
        menu.addItem(.separator())
        // Toggle Full Screen is a native NSWindow role.
        let fullScreenItem = NSMenuItem(
            title: "Enter Full Screen",
            action: #selector(NSWindow.toggleFullScreen(_:)),
            keyEquivalent: "f"
        )
        fullScreenItem.target = nil
        fullScreenItem.keyEquivalentModifierMask = [.command, .control]
        menu.addItem(fullScreenItem)
        return menu
    }

    private static func buildRepositoryMenu(openInEditorAction: Selector) -> NSMenu {
        let menu = NSMenu(title: "Repository")
        menu.addItem(responderItem("Push", key: "p", action: pushAction))
        menu.addItem(responderItem("Pull", key: "P", action: pullAction))
        menu.addItem(responderItem("Fetch", key: "T", action: fetchAction))
        menu.addItem(.separator())
        menu.addItem(responderItem("Show in Finder", key: "F", action: showInFinderAction))
        menu.addItem(responderItem("Open in Terminal", key: "`", modifiers: [.control], action: openInShellAction))
        // Open in External Editor is wired to AppDelegate, so use a concrete target.
        let editorItem = NSMenuItem(title: "Open in External Editor", action: openInEditorAction, keyEquivalent: "a")
        editorItem.target = NSApp.delegate
        editorItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(editorItem)
        menu.addItem(.separator())
        // ⌘⌫ — destructive but the confirmation alert lives in the handler.
        menu.addItem(responderItem("Remove…", key: "\u{8}", action: removeRepositoryAction))
        return menu
    }

    private static func buildBranchMenu() -> NSMenu {
        let menu = NSMenu(title: "Branch")
        menu.addItem(responderItem("New Branch…", key: "N", action: newBranchAction))
        menu.addItem(responderItem("Rename…", key: "R", action: renameBranchAction))
        menu.addItem(responderItem("Delete…", key: "D", action: deleteBranchAction))
        menu.addItem(.separator())
        menu.addItem(responderItem("Discard All Changes…", key: "\u{8}", modifiers: [.command, .shift], action: discardAllChangesAction))
        menu.addItem(responderItem("Stash All Changes", key: "S", action: stashAllChangesAction))
        menu.addItem(responderItem("Update from Default Branch", key: "U", action: updateFromDefaultAction))
        menu.addItem(.separator())
        menu.addItem(responderItem("Compare to Branch", key: "B", action: compareToBranchAction))
        menu.addItem(responderItem("Merge into Current Branch…", key: "M", action: mergeIntoCurrentAction))
        menu.addItem(responderItem("Squash and Merge into Current Branch…", key: "H", action: squashAndMergeAction))
        menu.addItem(responderItem("Rebase Current Branch…", key: "E", action: rebaseAction))
        return menu
    }

    private static func buildWindowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(responderItem("Minimize", key: "m", action: #selector(NSWindow.performMiniaturize(_:))))
        menu.addItem(responderItem("Zoom", action: #selector(NSWindow.performZoom(_:))))
        menu.addItem(responderItem("Close Window", key: "w", action: #selector(NSWindow.performClose(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Bring All to Front", target: NSApp, action: #selector(NSApplication.arrangeInFront(_:))))
        return menu
    }

    private static func buildHelpMenu(actionTarget: AnyObject, placeholderAction: Selector) -> NSMenu {
        let menu = NSMenu(title: "Help")
        menu.addItem(item("GimMac Help", key: "?", modifiers: [.command, .shift], target: actionTarget, action: placeholderAction))
        menu.addItem(item("Keyboard Shortcuts", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Release Notes", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Report Issue…", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Show Logs in Finder", target: actionTarget, action: placeholderAction))
        return menu
    }
}
