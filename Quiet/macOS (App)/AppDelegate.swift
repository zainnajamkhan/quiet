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
    private var mainWindow: NSWindow?
    private var blocker: AppBlockerService?
    private var blockingModel: BlockingModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let blocker = AppBlockerService(policyProvider: { BlockPolicyStore.load() })
        blocker.start()
        self.blocker = blocker
        self.blockingModel = BlockingModel(blocker: blocker)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let symbol = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Quiet") {
            item.button?.image = symbol
        } else {
            item.button?.title = "Quiet"
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Open Quiet…", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Quiet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item

        showMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        blocker?.stop()
    }

    @objc private func showMainWindow() {
        blockingModel?.refreshAccessibility()

        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let blockingModel else { return }
        let root = MainWindowView(ruleEditor: RuleEditorLoader.makeView(), blockingModel: blockingModel)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quiet"
        window.contentView = NSHostingView(rootView: root)
        window.center()
        window.isReleasedWhenClosed = false

        mainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

}
