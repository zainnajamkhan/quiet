//
//  RuleEditorView.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import SwiftUI
import QuietCore

struct RuleEditorView: View {

    let ruleset: Ruleset
    @ObservedObject var purchases: PurchaseModel
    var onShowPro: () -> Void = {}

    @State private var preferences: [String: Bool]

    init(
        ruleset: Ruleset,
        initialPreferences: [String: Bool],
        purchases: PurchaseModel,
        onShowPro: @escaping () -> Void = {}
    ) {
        self.ruleset = ruleset
        self.purchases = purchases
        self.onShowPro = onShowPro
        _preferences = State(initialValue: initialPreferences)
    }

    private var remainingFreeSites: Int {
        FreeTierPolicy.remainingFreeSites(ruleset: ruleset, preferences: preferences)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !SharedStateStore.isUsingAppGroup {
                NoticeBar(
                    symbol: "exclamationmark.triangle.fill",
                    message: "Settings are not reaching the extension. Nothing will be hidden.",
                    actionTitle: "Details",
                    tint: .red
                ) {}
                .help(SharedStateStore.storageDescription)
            } else if !purchases.isPro {
                NoticeBar(
                    symbol: "sparkles",
                    message: freeTierMessage,
                    actionTitle: "See Quiet Pro",
                    tint: .accentColor,
                    action: onShowPro
                )
            }

            Form {
                ForEach(ruleset.sites) { site in
                    Section {
                        ForEach(site.features) { feature in
                            featureRow(feature, in: site)
                        }
                    } header: {
                        HStack(spacing: 8) {
                            SiteMonogram(domain: site.name, size: 20)
                            Text(site.name)
                        }
                    }
                }

            }
            .formStyle(.grouped)
        }
    }

    private var freeTierMessage: String {
        remainingFreeSites > 0
            ? "Free on \(FreeTierPolicy.freeSiteLimit) sites at a time. \(remainingFreeSites) left."
            : "You are using both free sites. Unlock the rest with Quiet Pro."
    }

    @ViewBuilder
    private func featureRow(_ feature: Feature, in site: Site) -> some View {
        let allowed = FreeTierPolicy.canEnable(
            feature: feature,
            in: site,
            ruleset: ruleset,
            preferences: preferences,
            isPro: purchases.isPro
        )

        Toggle(isOn: binding(for: feature)) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(feature.name)
                    if let summary = feature.summary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                // A lock rather than a sentence per row. The explanation is identical on
                // every locked row, so repeating it turned the list into a wall of orange.
                if !allowed {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Needs Quiet Pro: you are already using your \(FreeTierPolicy.freeSiteLimit) free sites.")
                }
            }
        }
        .disabled(!allowed)
    }

    private func binding(for feature: Feature) -> Binding<Bool> {
        Binding(
            get: { FeatureResolution.isEnabled(feature, preferences: preferences) },
            set: { newValue in
                preferences[feature.id] = newValue
                persist()
            }
        )
    }

    private func persist() {
        let existing = SharedStateStore.load()
        try? SharedStateStore.save(
            SharedState(preferences: preferences, blockedHosts: existing.blockedHosts)
        )
    }
}

enum RuleEditorLoader {
    static func loadRuleset() -> Ruleset? {
        guard let url = Bundle.main.url(forResource: "ruleset", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let ruleset = try? Ruleset.decode(from: data)
        else { return nil }
        return ruleset
    }


}
