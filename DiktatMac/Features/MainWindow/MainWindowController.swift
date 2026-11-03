import AppKit
import SwiftUI

/// The optional main window. Diktat lives in the menu bar; the window opens from "Diktat öffnen". The Dock
/// icon shows only while the window is open, and goes away again when it closes.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private let appState: AppState
    private var window: NSWindow?

    init(appState: AppState) {
        self.appState = appState
    }

    var isOpen: Bool { window?.isVisible == true }

    func show(page: MainWindowPage? = nil) {
        if let page { appState.mainWindowPage = page }
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = Self.makeMainMenu()
        let window = window ?? makeWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    #if DEBUG || PILLDEMO
    /// Design check: the window content as an image, and a close as the close button does it.
    func debugImage() -> NSBitmapImageRep? {
        guard let view = window?.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    func debugClose() { window?.performClose(nil) }
    #endif

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Diktat"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 880, height: 580)
        window.contentView = NSHostingView(rootView: MainWindowView(appState: appState))
        window.delegate = self
        if !window.setFrameUsingName(Self.frameName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameName)
        return window
    }

    private static let frameName = "DiktatMainWindow"

    /// A small menu for as long as the window is open: Quit, the edit commands for text fields, Close and Minimize.
    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "Diktat ausblenden"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Diktat beenden"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: String(localized: "Bearbeiten"))
        editMenu.addItem(withTitle: String(localized: "Widerrufen"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: String(localized: "Wiederholen"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: String(localized: "Ausschneiden"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: String(localized: "Kopieren"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: String(localized: "Einsetzen"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: String(localized: "Alles auswählen"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: String(localized: "Fenster"))
        windowMenu.addItem(withTitle: String(localized: "Minimieren"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: String(localized: "Schließen"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        return main
    }
}
