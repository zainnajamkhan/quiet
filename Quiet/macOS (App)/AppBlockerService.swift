//
//  AppBlockerService.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import AppKit
import QuietCore
import os.log

/// Suppresses blocked applications while blocking is active.
///
/// This hides rather than terminates, deliberately. A sandboxed Mac App Store app cannot
/// call NSRunningApplication.terminate() on another app: it returns false, and the only
/// sanctioned alternative requires enumerating specific bundle identifiers in an
/// entitlement Apple must approve, which rules out "block whatever the user picks".
/// Hiding needs no special entitlement and works on any app chosen at runtime.
///
/// The honest tradeoff: this is suppression, not prevention. A determined user sees the
/// app for a moment before it is hidden again, and can keep reopening it. That matches
/// what comparable tools actually achieve and should be described that way rather than
/// sold as unbreakable.
@MainActor
final class AppBlockerService {

    private var observers: [NSObjectProtocol] = []
    private var isRunning = false

    private let policyProvider: () -> BlockPolicy
    private let sessionProvider: () -> BlockSession?

    init(
        policyProvider: @escaping () -> BlockPolicy,
        sessionProvider: @escaping () -> BlockSession? = { nil }
    ) {
        self.policyProvider = policyProvider
        self.sessionProvider = sessionProvider
    }

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system's Accessibility permission prompt. Returns the trust state as it
    /// was at call time, which is normally false on first run: macOS grants the permission
    /// out of band, so callers must re-check later rather than treat this as the answer.
    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ] {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                MainActor.assumeIsolated { self?.enforce(on: app) }
            }
            observers.append(observer)
        }

        // Anything already running when a session starts must be caught too, not just apps
        // launched afterwards.
        enforceOnAllRunningApplications()
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
        isRunning = false
    }

    func enforceOnAllRunningApplications() {
        for app in NSWorkspace.shared.runningApplications {
            enforce(on: app)
        }
    }

    private func enforce(on app: NSRunningApplication) {
        guard let bundleIdentifier = app.bundleIdentifier else { return }
        guard bundleIdentifier != Bundle.main.bundleIdentifier else { return }

        let blocked = BlockEvaluator.isApplicationBlocked(
            bundleIdentifier: bundleIdentifier,
            policy: policyProvider(),
            session: sessionProvider(),
            now: Date(),
            moment: ScheduleMoment.now()
        )
        guard blocked else { return }

        if !app.hide() {
            os_log(.default, "Quiet could not hide %{public}@", bundleIdentifier)
        }
    }
}
