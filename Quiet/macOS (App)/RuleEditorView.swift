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
    @State private var preferences: [String: Bool]

    init(ruleset: Ruleset, initialPreferences: [String: Bool]) {
        self.ruleset = ruleset
        _preferences = State(initialValue: initialPreferences)
    }

    var body: some View {
        List {
            ForEach(ruleset.sites) { site in
                Section(site.name) {
                    ForEach(site.features) { feature in
                        Toggle(isOn: binding(for: feature)) {
                            VStack(alignment: .leading) {
                                Text(feature.name)
                                if let summary = feature.summary {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 320)
        .navigationTitle("Quiet Rules")
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
        try? SharedStateStore.save(SharedState(preferences: preferences))
    }
}

enum RuleEditorLoader {
    /// Loads the app's own bundled copy of the ruleset (kept in sync by hand with the
    /// extension's copy for now, see Tools/test.sh) merged with whatever the shared state
    /// file already has, so reopening the window does not reset every toggle to default.
    static func makeView() -> RuleEditorView? {
        guard let url = Bundle.main.url(forResource: "ruleset", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let ruleset = try? Ruleset.decode(from: data)
        else { return nil }

        let stored = SharedStateStore.load().preferences
        return RuleEditorView(ruleset: ruleset, initialPreferences: stored)
    }
}
