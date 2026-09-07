//
//  HelpView.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import AppKit
import SwiftUI
import QuietCore

/// Version information, where the rules come from, and how to reach a person.
///
/// Also the home for the rules version, which used to sit at the bottom of the Hide screen.
/// It matters when something breaks, but it is not something anyone needs while deciding
/// which parts of YouTube to switch off.
struct HelpView: View {

    @ObservedObject var updates: RulesetUpdateService

    static let supportAddress = "zainnajam2424@gmail.com"
    static let privacyURL = URL(string: "https://zainnajamkhan.github.io/quiet-rules/privacy.html")!

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section("Something not working?") {
                Text("If a site changed and Quiet stopped hiding something, or anything else looks wrong, send an email. Bug reports about a specific site are especially useful.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(Self.supportAddress)
                        .textSelection(.enabled)
                    Spacer()
                    Button("Send Email…") { composeSupportEmail() }
                }
            }

            Section("Rules") {
                LabeledContent("Version") {
                    Text(updates.effectiveRulesetVersion.map(String.init) ?? "unknown")
                        .monospacedDigit()
                }

                if updates.isConfigured {
                    HStack {
                        Text(updates.state.lastResult ?? "Not checked yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Check Now") { Task { await updates.check() } }
                            .controlSize(.small)
                            .disabled(updates.isChecking)
                    }
                } else {
                    Text("Using the rules that shipped with this version of Quiet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Quiet", value: appVersion)
                Link("Privacy policy", destination: Self.privacyURL)
            }
        }
        .formStyle(.grouped)
    }

    /// Pre-fills the version and the rules version, because they are the first two things
    /// worth knowing about a bug report and the last two anyone thinks to include.
    private func composeSupportEmail() {
        let rules = updates.effectiveRulesetVersion.map(String.init) ?? "unknown"
        let subject = "Quiet \(appVersion)"
        let body = """


        ---
        Quiet \(appVersion)
        Rules version \(rules)
        macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.supportAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }
}
