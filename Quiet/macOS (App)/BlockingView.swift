//
//  BlockingView.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import QuietCore

@MainActor
final class BlockingModel: ObservableObject {

    @Published var policy: BlockPolicy
    @Published var newHost: String = ""
    @Published var hostError: String?
    @Published var isAccessibilityTrusted: Bool

    private let blocker: AppBlockerService
    private var accessibilityObserver: NSObjectProtocol?

    init(blocker: AppBlockerService) {
        self.blocker = blocker
        self.policy = BlockPolicyStore.load()
        self.isAccessibilityTrusted = blocker.isAccessibilityTrusted
    }

    /// A blocklist with no schedule blocks nothing, which would look configured and do
    /// nothing at all. Adding the first entry turns blocking on.
    private func ensureSchedule(in policy: BlockPolicy) -> BlockPolicy {
        policy.schedules.isEmpty ? policy.settingBlocksAlways(true) : policy
    }

    func addHost() {
        let trimmed = newHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let pattern = HostPattern(trimmed) else {
            hostError = "\"\(trimmed)\" is not a website address."
            return
        }
        guard !policy.blockedHosts.contains(pattern) else {
            hostError = "\(pattern.domain) is already blocked."
            return
        }
        hostError = nil
        newHost = ""
        policy = ensureSchedule(in: policy.with(blockedHosts: policy.blockedHosts + [pattern]))
        persist()
    }

    func removeHost(_ pattern: HostPattern) {
        policy = policy.with(blockedHosts: policy.blockedHosts.filter { $0 != pattern })
        persist()
    }

    func removeApplication(_ app: BlockedApplication) {
        policy = policy.with(blockedApplications: policy.blockedApplications.filter { $0.id != app.id })
        persist()
    }

    func chooseApplications() {
        let panel = NSOpenPanel()
        panel.title = "Choose apps to block"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }

        var added = policy.blockedApplications
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { continue }
            guard !added.contains(where: { $0.id == identifier }) else { continue }
            let name = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            added.append(BlockedApplication(id: identifier, name: name))
        }

        policy = ensureSchedule(in: policy.with(blockedApplications: added))
        persist()
    }

    func requestAccessibility() {
        blocker.requestAccessibilityPermission()
        // macOS grants this out of band, so re-check shortly rather than trusting the
        // immediate return value, which is false while the prompt is still open.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            self.isAccessibilityTrusted = self.blocker.isAccessibilityTrusted
        }
    }

    /// Granting happens in System Settings, so the app finds out by looking again when the
    /// user comes back to it. Without this the banner stays up after the permission has
    /// actually been given, which reads as the grant not having worked.
    func startWatchingAccessibility() {
        guard accessibilityObserver == nil else { return }
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccessibility() }
        }
    }

    func refreshAccessibility() {
        isAccessibilityTrusted = blocker.isAccessibilityTrusted
    }

    private func persist() {
        try? BlockPolicyStore.save(policy)
        publishBlockedHostsToExtension()
        blocker.enforceOnAllRunningApplications()
    }

    /// The extension has no clock or schedule logic of its own, so the app resolves the
    /// currently blocked hosts and hands over a flat list.
    private func publishBlockedHostsToExtension() {
        let hosts = BlockEvaluator.currentlyBlockedHosts(
            policy: policy,
            session: nil,
            now: Date(),
            moment: ScheduleMoment.now()
        )
        let existing = SharedStateStore.load()
        try? SharedStateStore.save(SharedState(preferences: existing.preferences, blockedHosts: hosts))
    }
}

struct BlockingView: View {

    @ObservedObject var model: BlockingModel
    @ObservedObject var purchases: PurchaseModel
    var onShowPro: () -> Void = {}

    private var isLocked: Bool { !purchases.isPro }

    private static let appsNote = """
    Blocked apps are hidden when they open, not quit. macOS does not let a sandboxed app \
    quit another one, so a determined user can still reopen them.
    """

    var body: some View {
        VStack(spacing: 0) {
            if isLocked {
                NoticeBar(
                    symbol: "lock.fill",
                    message: "Blocking is part of Quiet Pro.",
                    actionTitle: "See Quiet Pro",
                    tint: .accentColor,
                    action: onShowPro
                )
            } else if !model.isAccessibilityTrusted && !model.policy.blockedApplications.isEmpty {
                NoticeBar(
                    symbol: "exclamationmark.triangle.fill",
                    message: "Quiet needs Accessibility permission to hide blocked apps.",
                    actionTitle: "Open Settings…",
                    tint: .orange
                ) {
                    model.requestAccessibility()
                }
            }

            Form {
                websites
                apps
            }
            .formStyle(.grouped)
        }
        .onAppear {
            model.refreshAccessibility()
            model.startWatchingAccessibility()
        }
    }

    // MARK: - Websites

    private var websites: some View {
        Section("Websites") {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tertiary)
                TextField("youtube.com", text: $model.newHost)
                    .textFieldStyle(.plain)
                    .onSubmit { model.addHost() }
                Button("Add") { model.addHost() }
                    .disabled(model.newHost.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .disabled(isLocked)

            if let error = model.hostError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if model.policy.blockedHosts.isEmpty {
                EmptyHint(symbol: "globe", text: "No websites blocked yet.")
            } else {
                ForEach(model.policy.blockedHosts, id: \.self) { host in
                    RemovableRow(onRemove: { model.removeHost(host) }, isRemovable: !isLocked) {
                        SiteMonogram(domain: host.domain)
                        Text(host.domain)
                    }
                }
            }
        }
    }

    // MARK: - Apps

    private var apps: some View {
        Section {
            if model.policy.blockedApplications.isEmpty {
                EmptyHint(symbol: "macwindow", text: "No apps blocked yet.")
            } else {
                ForEach(model.policy.blockedApplications) { app in
                    RemovableRow(onRemove: { model.removeApplication(app) }, isRemovable: !isLocked) {
                        AppIconView(bundleIdentifier: app.id)
                        Text(app.name)
                    }
                }
            }
        } header: {
            HStack(spacing: 6) {
                Text("Apps")
                InfoButton(text: Self.appsNote)
                Spacer()
                Button("Add Apps…") { model.chooseApplications() }
                    .controlSize(.small)
                    .disabled(isLocked)
            }
        }
    }
}
