import AppKit

@MainActor
enum MainMenuFactory {
    static func buildMainMenu(
        actionTarget: AnyObject,
        placeholderAction: Selector,
        aboutAction: Selector,
        settingsAction: Selector
    ) -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem(title: "GimMac", action: nil, keyEquivalent: "")
        appMenuItem.submenu = buildAppMenu(
            actionTarget: actionTarget,
            placeholderAction: placeholderAction,
            aboutAction: aboutAction,
            settingsAction: settingsAction
        )
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = buildFileMenu(actionTarget: actionTarget, placeholderAction: placeholderAction)
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = buildEditMenu(actionTarget: actionTarget, placeholderAction: placeholderAction)
        mainMenu.addItem(editMenuItem)

        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        viewMenuItem.submenu = buildViewMenu(actionTarget: actionTarget, placeholderAction: placeholderAction)
        mainMenu.addItem(viewMenuItem)

        let goMenuItem = NSMenuItem(title: "Go", action: nil, keyEquivalent: "")
        goMenuItem.submenu = buildGoMenu(actionTarget: actionTarget, placeholderAction: placeholderAction)
        mainMenu.addItem(goMenuItem)

        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowMenuItem.submenu = buildWindowMenu(actionTarget: actionTarget, placeholderAction: placeholderAction)
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
        action: Selector
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = target
        menuItem.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
        return menuItem
    }

    private static func buildAppMenu(
        actionTarget: AnyObject,
        placeholderAction: Selector,
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

    private static func buildFileMenu(actionTarget: AnyObject, placeholderAction: Selector) -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(item("New File…", key: "n", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Open File…", key: "o", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Open Folder…", target: actionTarget, action: placeholderAction))

        let openRecentItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        openRecentItem.submenu = NSMenu(title: "Open Recent")
        menu.addItem(openRecentItem)

        menu.addItem(.separator())
        menu.addItem(item("Close File", key: "w", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Save", key: "s", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Save As…", key: "S", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Duplicate", key: "d", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Move To…", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Rename…", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Revert To Saved", target: actionTarget, action: placeholderAction))
        return menu
    }

    private static func buildEditMenu(actionTarget: AnyObject, placeholderAction: Selector) -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(item("Undo", key: "z", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Redo", key: "Z", target: actionTarget, action: placeholderAction))
        menu.addItem(.separator())
        menu.addItem(item("Cut", key: "x", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Copy", key: "c", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Paste", key: "v", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Paste and Match Style", key: "V", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Delete", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Select All", key: "a", target: actionTarget, action: placeholderAction))
        menu.addItem(.separator())
        menu.addItem(item("Find", key: "f", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Find Next", key: "g", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Find Previous", key: "G", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Replace…", target: actionTarget, action: placeholderAction))
        return menu
    }

    private static func buildViewMenu(actionTarget: AnyObject, placeholderAction: Selector) -> NSMenu {
        let menu = NSMenu(title: "View")
        menu.addItem(item("Show Sidebar", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Show Toolbar", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Show Status Bar", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Show Tab Bar", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Enter Full Screen", key: "f", modifiers: [.command, .control], target: actionTarget, action: placeholderAction))
        return menu
    }

    private static func buildGoMenu(actionTarget: AnyObject, placeholderAction: Selector) -> NSMenu {
        let menu = NSMenu(title: "Go")
        menu.addItem(item("Back", key: "[", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Forward", key: "]", target: actionTarget, action: placeholderAction))
        menu.addItem(.separator())
        menu.addItem(item("Go to File…", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Go to Line…", key: "l", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Go to Symbol…", target: actionTarget, action: placeholderAction))
        return menu
    }

    private static func buildWindowMenu(actionTarget: AnyObject, placeholderAction: Selector) -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(item("Minimize", key: "m", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Zoom", target: actionTarget, action: placeholderAction))
        menu.addItem(item("Close Window", key: "w", target: actionTarget, action: placeholderAction))
        menu.addItem(.separator())
        menu.addItem(item("Bring All to Front", target: actionTarget, action: placeholderAction))
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
