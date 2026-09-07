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

    init(blocker: AppBlockerService) {
        self.blocker = blocker
        self.policy = BlockPolicyStore.load()
        self.isAccessibilityTrusted = blocker.isAccessibilityTrusted
    }

    /// Blocking is only meaningful once something turns it on. A single always-on schedule
    /// is created the first time the user adds anything, so the feature does not silently
    /// do nothing while looking configured.
    private func ensureSchedule(in policy: BlockPolicy) -> BlockPolicy {
        guard policy.schedules.isEmpty else { return policy }
        return BlockPolicy(
            blockedApplications: policy.blockedApplications,
            blockedHosts: policy.blockedHosts,
            schedules: [Schedule(id: "always", kind: .always, enabled: true)]
        )
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
        policy = ensureSchedule(in: BlockPolicy(
            blockedApplications: policy.blockedApplications,
            blockedHosts: policy.blockedHosts + [pattern],
            schedules: policy.schedules
        ))
        persist()
    }

    func removeHost(_ pattern: HostPattern) {
        policy = BlockPolicy(
            blockedApplications: policy.blockedApplications,
            blockedHosts: policy.blockedHosts.filter { $0 != pattern },
            schedules: policy.schedules
        )
        persist()
    }

    func removeApplication(_ app: BlockedApplication) {
        policy = BlockPolicy(
            blockedApplications: policy.blockedApplications.filter { $0.id != app.id },
            blockedHosts: policy.blockedHosts,
            schedules: policy.schedules
        )
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

        policy = ensureSchedule(in: BlockPolicy(
            blockedApplications: added,
            blockedHosts: policy.blockedHosts,
            schedules: policy.schedules
        ))
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

    var body: some View {
        List {
            if !model.isAccessibilityTrusted {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Accessibility permission needed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Quiet hides blocked apps using macOS Accessibility. Without this permission, website blocking still works but apps will not be hidden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Grant Permission…") { model.requestAccessibility() }
                            Button("Re-check") { model.refreshAccessibility() }
                        }
                    }
                }
            }

            Section("Blocked websites") {
                HStack {
                    TextField("youtube.com", text: $model.newHost)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { model.addHost() }
                    Button("Add") { model.addHost() }
                }
                if let error = model.hostError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                if model.policy.blockedHosts.isEmpty {
                    Text("No websites blocked.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.policy.blockedHosts, id: \.self) { host in
                    HStack {
                        Text(host.domain)
                        Spacer()
                        Button("Remove") { model.removeHost(host) }
                            .buttonStyle(.borderless)
                    }
                }
            }

            Section("Blocked apps") {
                Button("Choose Apps…") { model.chooseApplications() }
                if model.policy.blockedApplications.isEmpty {
                    Text("No apps blocked.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.policy.blockedApplications) { app in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(app.name)
                            Text(app.id).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Remove") { model.removeApplication(app) }
                            .buttonStyle(.borderless)
                    }
                }
            }

            Section {
                Text("Blocked apps are hidden when they open, not force quit: macOS does not let a sandboxed app quit another one. A determined user can still reopen them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 460, minHeight: 420)
    }
}
