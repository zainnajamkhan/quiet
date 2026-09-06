//
//  AppDelegate.swift
//  macOS (App)
//
//  Created by Zain Najam Khan 1 on 06/09/2026.
//

import Cocoa
import SwiftUI
import QuietCore

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var rulesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let symbol = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Quiet") {
            item.button?.image = symbol
        } else {
            // Falls back to visible text rather than risk a blank, easy to miss square if
            // the symbol fails to load for any reason.
            item.button?.title = "Quiet"
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Rules…", action: #selector(showRules), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Quiet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu

        statusItem = item


        // The status item alone is too easy to miss: on a Mac with a notch or a busy menu
        // bar, macOS silently pushes new items into an overflow area. Opening the rules
        // window on launch makes the app's actual UI unmissable, rather than depending on
        // the user finding an icon that may not be visible at all.
        showRules()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @objc private func showRules() {
        if let rulesWindow {
            rulesWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let view = RuleEditorLoader.makeView() else {
            let alert = NSAlert()
            alert.messageText = "Could not load rules"
            alert.informativeText = "ruleset.json is missing from the app bundle or could not be parsed."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quiet Rules"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false

        rulesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

}
