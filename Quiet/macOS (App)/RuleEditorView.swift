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
    @State private var preferences: [String: Bool]

    init(ruleset: Ruleset, initialPreferences: [String: Bool], purchases: PurchaseModel) {
        self.ruleset = ruleset
        self.purchases = purchases
        _preferences = State(initialValue: initialPreferences)
    }

    private var remainingFreeSites: Int {
        FreeTierPolicy.remainingFreeSites(ruleset: ruleset, preferences: preferences)
    }

    var body: some View {
        List {
            if !SharedStateStore.isUsingAppGroup {
                Section {
                    Label(SharedStateStore.storageDescription, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }

            if !purchases.isPro {
                Section {
                    PaywallView(purchases: purchases)
                    Text("Free: \(FreeTierPolicy.freeSiteLimit) sites at a time. \(remainingFreeSites) remaining.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(ruleset.sites) { site in
                Section(site.name) {
                    ForEach(site.features) { feature in
                        featureRow(feature, in: site)
                    }
                }
            }
        }
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
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.name)
                if let summary = feature.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !allowed {
                    Text("Needs Quiet Pro: you are using your \(FreeTierPolicy.freeSiteLimit) free sites.")
                        .font(.caption)
                        .foregroundStyle(.orange)
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

    static func makeView(purchases: PurchaseModel) -> RuleEditorView? {
        guard let ruleset = loadRuleset() else { return nil }
        return RuleEditorView(
            ruleset: ruleset,
            initialPreferences: SharedStateStore.load().preferences,
            purchases: purchases
        )
    }
}
