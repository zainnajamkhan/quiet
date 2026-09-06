//
//  FeatureResolution.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

public enum FeatureResolution {

    /// Preferences are keyed on the stable feature identifier and may be partial. An absent
    /// key means the feature's own default applies, which is what lets a ruleset update
    /// change selectors without disturbing anything the customer has chosen.
    public static func isEnabled(_ feature: Feature, preferences: [String: Bool]) -> Bool {
        preferences[feature.id] ?? feature.defaultEnabled
    }

    public static func applies(_ feature: Feature, to urlString: String) -> Bool {
        guard let appliesTo = feature.appliesTo, !appliesTo.isEmpty else { return true }
        guard let components = URLComponents(string: urlString),
              components.scheme != nil,
              let host = components.host,
              !host.isEmpty
        else { return false }

        let pathAndQuery = MatchPattern.pathAndQuery(of: components)
        return appliesTo.contains { MatchPattern.glob($0, matches: pathAndQuery) }
    }

    public static func activeFeatures(
        in site: Site,
        url urlString: String,
        preferences: [String: Bool]
    ) -> [Feature] {
        site.features.filter { feature in
            isEnabled(feature, preferences: preferences) && applies(feature, to: urlString)
        }
    }

    public static func site(in ruleset: Ruleset, matching urlString: String) -> Site? {
        guard RulesetValidator.isValid(ruleset) else { return nil }
        return ruleset.sites.first { site in
            site.matches.contains { pattern in
                MatchPattern(pattern)?.matches(urlString) == true
            }
        }
    }
}
