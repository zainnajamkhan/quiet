//
//  FocusMonitor.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import AppIntents
import AppKit
import Combine
import QuietCore
import os.log

/// Keeps Quiet's idea of the running Focus in step with the system's.
///
/// Two mechanisms, because neither is sufficient alone. The push, `QuietFocusFilter.perform`,
/// is prompt but only arrives while some Quiet process is alive to receive it, so a Focus
/// that starts or ends while Quiet is quit is missed entirely. The pull,
/// `QuietFocusFilter.current`, is authoritative at any moment but has to be asked. So the
/// push updates immediately and the pull reconciles: on launch, whenever the app is brought
/// to the front, and shortly after each push.
///
/// The delayed reconcile after a push is not belt and braces. Switching straight from one
/// Focus to another produces two performs, one clearing and one setting, and nothing
/// documents their order. If the clear lands second, blocking is left off while a Focus is
/// still running; the reconcile puts that right within a couple of seconds.
@MainActor
final class FocusMonitor: ObservableObject {

    @Published private(set) var activeIdentifiers: [String] = []

    /// Set when the system could be reached but gave an answer Quiet could not interpret,
    /// so the UI can say "unknown" rather than confidently claim no Focus is running.
    @Published private(set) var lastReconcileFailed = false

    /// Called whenever the active Focus actually changes, so enforcement and the hosts
    /// handed to the Safari extension can be recomputed.
    var onChange: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var reconcileTask: Task<Void, Never>?

    var isFocusActive: Bool { !activeIdentifiers.isEmpty }

    func start() {
        // Start from whatever was last written rather than from nothing: if the app was
        // relaunched during a Focus, this is right, and the reconcile below confirms it.
        activeIdentifiers = FocusStateStore.load().activeIdentifiers

        FocusChangeSignal.startObserving()

        observers.append(NotificationCenter.default.addObserver(
            forName: .quietFocusDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handlePush() }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleReconcile(after: .zero) }
        })

        scheduleReconcile(after: .zero)
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        reconcileTask?.cancel()
        reconcileTask = nil
    }

    /// The intent already wrote the new state, so read it straight away for a prompt
    /// response, then confirm it.
    private func handlePush() {
        apply(FocusStateStore.load().activeIdentifiers, persist: false)
        scheduleReconcile(after: .seconds(2))
    }

    private func scheduleReconcile(after delay: Duration) {
        reconcileTask?.cancel()
        reconcileTask = Task { [weak self] in
            if delay != .zero {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
            }
            await self?.reconcile()
        }
    }

    func reconcile() async {
        do {
            let current = try await QuietFocusFilter.current
            lastReconcileFailed = false
            apply(current.profile.map { [$0.id] } ?? [])
        } catch SetFocusFilterIntentError.notFound {
            // Nothing has this filter applied, which is the ordinary "no Focus is running"
            // answer rather than a failure.
            lastReconcileFailed = false
            apply([])
        } catch {
            // Any other failure leaves the last known state alone. Guessing in either
            // direction is worse than being briefly stale: guessing "off" unblocks
            // everything mid Focus, guessing "on" blocks when the user did not ask.
            lastReconcileFailed = true
            os_log(.default, "Quiet could not read the current Focus filter: %{public}@", String(describing: error))
        }
    }

    private func apply(_ identifiers: [String], persist: Bool = true) {
        guard identifiers != activeIdentifiers else { return }
        activeIdentifiers = identifiers
        if persist {
            if let identifier = identifiers.first {
                FocusStateStore.activate(identifier)
            } else {
                FocusStateStore.clear()
            }
        }
        onChange?()
    }
}
