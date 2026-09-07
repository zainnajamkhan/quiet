//
//  MainWindowView.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import SwiftUI
import QuietCore

/// A sidebar rather than the tab strip this used to use. Two tabs read as a dialog; a
/// sidebar reads as an app, gives each screen its own full width, and leaves somewhere
/// obvious to put Quiet Pro without wedging a paywall on top of the settings.
struct MainWindowView: View {

    /// The ruleset rather than a prebuilt editor view, so this screen can hand the editor a
    /// way back to the Pro screen, and so preferences are re-read each time the screen is
    /// shown rather than frozen at the moment the window was created.
    let ruleset: Ruleset?
    @ObservedObject var blockingModel: BlockingModel
    @ObservedObject var purchases: PurchaseModel
    @ObservedObject var extensionStatus: ExtensionStatusModel
    @ObservedObject var updates: RulesetUpdateService

    enum Screen: String, CaseIterable, Identifiable {
        case hide
        case block
        case pro
        case help

        var id: String { rawValue }

        var title: String {
            switch self {
            case .hide: "Hide"
            case .block: "Block"
            case .pro: "Quiet Pro"
            case .help: "Help"
            }
        }

        var symbol: String {
            switch self {
            case .hide: "eye.slash"
            case .block: "hand.raised"
            case .pro: "sparkles"
            case .help: "questionmark.circle"
            }
        }

        var subtitle: String {
            switch self {
            case .hide: "Trim the noise out of sites"
            case .block: "Keep sites and apps shut"
            case .pro: "One payment, everything on"
            case .help: "Version, rules and support"
            }
        }
    }

    @State private var screen: Screen = .hide

    var body: some View {
        NavigationSplitView {
            List(Screen.allCases, selection: $screen) { item in
                NavigationLink(value: item) {
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: item.symbol)
                    }
                    .padding(.vertical, 3)
                }
            }
            .navigationSplitViewColumnWidth(min: 196, ideal: 208, max: 240)
        } detail: {
            VStack(spacing: 0) {
                if extensionStatus.state == .disabled {
                    NoticeBar(
                        symbol: "exclamationmark.triangle.fill",
                        message: "The Quiet extension is switched off in Safari.",
                        actionTitle: "Open Safari Settings…",
                        tint: .orange
                    ) {
                        extensionStatus.openSafariSettings()
                    }
                }

                detail
            }
            .navigationTitle(screen.title)
        }
        .frame(minWidth: 720, idealWidth: 800, minHeight: 460, idealHeight: 600)
        .onAppear { extensionStatus.refresh() }
    }

    @ViewBuilder
    private var detail: some View {
        switch screen {
        case .hide:
            if let ruleset {
                RuleEditorView(
                    ruleset: ruleset,
                    initialPreferences: SharedStateStore.load().preferences,
                    purchases: purchases,
                    onShowPro: { screen = .pro }
                )
            } else {
                ContentUnavailableView(
                    "Could not load rules",
                    systemImage: "exclamationmark.triangle",
                    description: Text("ruleset.json is missing from the app bundle or could not be read.")
                )
            }

        case .block:
            BlockingView(model: blockingModel, purchases: purchases, onShowPro: { screen = .pro })

        case .pro:
            ProScreen(purchases: purchases)

        case .help:
            HelpView(updates: updates)
        }
    }
}

/// The paywall on its own screen. Previously it sat at the top of both settings screens,
/// which meant the first thing anyone saw was a price rather than the thing they installed
/// the app to do.
struct ProScreen: View {
    @ObservedObject var purchases: PurchaseModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if purchases.isPro {
                    // Deliberately plain. A large seal badge here read as the app
                    // congratulating itself for having been paid for.
                    VStack(spacing: 6) {
                        Text("Quiet Pro is active")
                            .font(.title3.weight(.medium))
                        Text("Everything is unlocked.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    PaywallView(purchases: purchases)
                }
            }
            .frame(maxWidth: 460)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }
}
