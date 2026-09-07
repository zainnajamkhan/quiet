//
//  AppDelegate.swift
//  macOS (App)
//
//  Created by Zain Najam Khan 1 on 06/09/2026.
//

import Cocoa
import SwiftUI
import QuietCore

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var blocker: AppBlockerService?
    private var blockingModel: BlockingModel?
    private let purchases = PurchaseModel()
    private let extensionStatus = ExtensionStatusModel()
    private let updates = RulesetUpdateService(bundled: RuleEditorLoader.loadRuleset())
    private var onboardingWindow: NSWindow?

    private static let onboardingCompletedKey = "quiet.onboardingCompleted"
    private var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.onboardingCompletedKey) }
    }

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

        Task { await purchases.start() }
        Task { await updates.checkIfDue() }
        extensionStatus.refresh()

        if hasCompletedOnboarding {
            showMainWindow()
        } else {
            showOnboarding()
        }
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

    private func showOnboarding() {
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = OnboardingView(extensionStatus: extensionStatus) { [weak self] in
            guard let self else { return }
            self.hasCompletedOnboarding = true
            self.onboardingWindow?.close()
            self.onboardingWindow = nil
            self.showMainWindow()
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Quiet"
        window.contentView = NSHostingView(rootView: root)
        window.center()
        window.isReleasedWhenClosed = false

        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showMainWindow() {
        blockingModel?.refreshAccessibility()
        extensionStatus.refresh()

        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let blockingModel else { return }
        let root = MainWindowView(
            ruleset: RuleEditorLoader.loadRuleset(),
            blockingModel: blockingModel,
            purchases: purchases,
            extensionStatus: extensionStatus,
            updates: updates
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
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
