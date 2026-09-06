//
//  AppDelegate.swift
//  macOS (App)
//
//  Created by Zain Najam Khan 1 on 06/09/2026.
//

import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var rulesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Quiet")

        let menu = NSMenu()
        menu.addItem(withTitle: "Rules…", action: #selector(showRules), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Quiet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu

        statusItem = item
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

        guard let view = RuleEditorLoader.makeView() else { return }

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
