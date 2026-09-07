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
    @Published var newFocusName: String = ""
    @Published var focusError: String?
    @Published var isAccessibilityTrusted: Bool

    private let blocker: AppBlockerService
    private let focusProvider: () -> [String]

    init(blocker: AppBlockerService, focusProvider: @escaping () -> [String] = { [] }) {
        self.blocker = blocker
        self.focusProvider = focusProvider
        self.policy = BlockPolicyStore.load()
        self.isAccessibilityTrusted = blocker.isAccessibilityTrusted
    }

    /// Blocking is only meaningful once something turns it on. A single always-on schedule
    /// is created the first time the user adds anything, so the feature does not silently
    /// do nothing while looking configured.
    private func ensureSchedule(in policy: BlockPolicy) -> BlockPolicy {
        guard policy.schedules.isEmpty else { return policy }
        return policy.settingBlocksAlways(true)
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

    func refreshAccessibility() {
        isAccessibilityTrusted = blocker.isAccessibilityTrusted
    }

    // MARK: - Focus

    /// Blocking is either always on or driven by a Focus, never both: an always-on schedule
    /// alongside the Focus schedules would keep blocking after every Focus ended, which
    /// reads to the user as "Focus mode is broken".
    var blocksAlways: Bool {
        get { policy.blocksAlways }
        set {
            policy = policy.settingBlocksAlways(newValue)
            persist()
        }
    }

    var activeFocusIdentifiers: [String] { focusProvider() }

    /// The name to show for whatever Focus is currently driving Quiet. Falls back to the
    /// raw identifier so a link the user deleted while it was running still reads as
    /// something rather than vanishing.
    var activeFocusName: String? {
        guard let identifier = activeFocusIdentifiers.first else { return nil }
        if identifier == FocusPolicy.anyFocusIdentifier { return FocusPolicy.anyFocus.name }
        return policy.focusProfiles.first { $0.id == identifier }?.name ?? identifier
    }

    func addFocusProfile() {
        let name = newFocusName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard let profile = FocusPolicy.makeProfile(name: name, existing: policy.focusProfiles) else {
            focusError = "\"\(name)\" needs at least one letter or number."
            return
        }
        guard !policy.focusProfiles.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            focusError = "\(name) is already here."
            return
        }
        focusError = nil
        newFocusName = ""
        policy = policy.settingFocusProfiles(policy.focusProfiles + [profile])
        persist()
    }

    func removeFocusProfile(_ profile: FocusProfile) {
        policy = policy.settingFocusProfiles(policy.focusProfiles.filter { $0.id != profile.id })
        persist()
    }

    /// Re-runs enforcement after the system tells us a Focus started or ended. The policy
    /// has not changed, only the answer to "is it active right now", so this republishes
    /// and re-enforces without touching what is stored.
    func focusDidChange() {
        objectWillChange.send()
        publishBlockedHostsToExtension()
        blocker.enforceOnAllRunningApplications()
    }

    func openFocusSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private func persist() {
        try? BlockPolicyStore.save(policy)
        publishBlockedHostsToExtension()
        blocker.enforceOnAllRunningApplications()
    }

    /// The extension has no clock or schedule logic of its own, so the app resolves the
    /// currently blocked hosts and hands over a flat list.
    private func publishBlockedHostsToExtension(activeFocusIdentifiers: [String]? = nil) {
        let hosts = BlockEvaluator.currentlyBlockedHosts(
            policy: policy,
            session: nil,
            now: Date(),
            moment: ScheduleMoment.now(),
            activeFocusIdentifiers: activeFocusIdentifiers ?? focusProvider()
        )
        let existing = SharedStateStore.load()
        try? SharedStateStore.save(SharedState(preferences: existing.preferences, blockedHosts: hosts))
    }

    /// Drops any block that only exists because a Focus is running, just before Quiet stops
    /// running. Nothing would be left to notice that Focus ending, so the block would sit in
    /// Safari indefinitely and the only way to discover why would be to reopen Quiet.
    /// Blocks that do not depend on a Focus, such as "block all the time", are left alone.
    func prepareForTermination() {
        publishBlockedHostsToExtension(activeFocusIdentifiers: [])
    }
}

struct BlockingView: View {
    @ObservedObject var model: BlockingModel
    @ObservedObject var purchases: PurchaseModel
    @ObservedObject var focus: FocusMonitor

    /// Says plainly what Quiet currently believes, including that it does not know. A
    /// blocker that quietly guesses is worse than one that admits the gap.
    @ViewBuilder
    private var focusStatus: some View {
        if let name = model.activeFocusName {
            Label("\(name) is running, so Quiet is blocking.", systemImage: "moon.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if focus.lastReconcileFailed {
            Label("Quiet could not tell whether a Focus is running.", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Label("No Focus is running, so nothing is blocked.", systemImage: "moon")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Applied to the individual sections rather than to the List, because disabling the
    /// List disables its scrolling too: the content is taller than the window, so a locked
    /// Block tab could not be scrolled at all and the lower half was unreachable.
    private var isLocked: Bool { !purchases.isPro }

    var body: some View {
        List {
            if !purchases.isPro {
                Section {
                    PaywallView(purchases: purchases)
                    Text("Blocking sites and apps is part of Quiet Pro. Hiding distractions stays free.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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
                .disabled(isLocked)
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
            .disabled(isLocked)

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
            .disabled(isLocked)

            Section("When to block") {
                Picker("Block", selection: Binding(
                    get: { model.blocksAlways },
                    set: { model.blocksAlways = $0 }
                )) {
                    Text("All the time").tag(true)
                    Text("Only during a Focus").tag(false)
                }
                .pickerStyle(.radioGroup)

                if !model.blocksAlways {
                    focusStatus
                }
            }
            .disabled(isLocked)

            Section("Focus") {
                if model.blocksAlways {
                    Text("Not in use while Quiet is blocking all the time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("macOS does not let an app ask which Focus is running, so you connect them by hand: add a name here, then pick that name in System Settings under Focus Filters. Do this once per Focus.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Work", text: $model.newFocusName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { model.addFocusProfile() }
                    Button("Add") { model.addFocusProfile() }
                }
                .disabled(isLocked)

                if let error = model.focusError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }

                HStack {
                    Text(FocusPolicy.anyFocus.name)
                    Spacer()
                    Text("Offered in System Settings without adding anything here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.policy.focusProfiles) { profile in
                    HStack {
                        Text(profile.name)
                        Spacer()
                        Button("Remove") { model.removeFocusProfile(profile) }
                            .buttonStyle(.borderless)
                            .disabled(isLocked)
                    }
                }

                // Deliberately not gated behind Pro. This only opens System Settings, and
                // adding Quiet as a Focus Filter is a one time OS level step someone may
                // reasonably want to do, or just look at, before paying. A disabled button
                // here reads as the app being broken rather than as a locked feature.
                Button("Open Focus Settings…") { model.openFocusSettings() }
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
