//
//  RulesetValidator.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

public enum RulesetValidator {

    /// Characters that would let a selector escape the stylesheet rule or comment it is
    /// injected into. The combinators `>`, `~` and `+` stay legal.
    private static let unsafeInSelector: Set<Character> = ["{", "}", ";", "<"]

    public static func isSafeSelector(_ selector: String) -> Bool {
        guard !selector.isEmpty else { return false }
        guard !selector.contains(where: { unsafeInSelector.contains($0) }) else { return false }
        return !selector.contains("*/")
    }

    public static func isValidIdentifier(_ identifier: String) -> Bool {
        guard !identifier.isEmpty else { return false }
        let segments = identifier.split(separator: "-", omittingEmptySubsequences: false)
        return segments.allSatisfy { segment in
            !segment.isEmpty && segment.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) }
        }
    }

    public static func isValidFeatureIdentifier(_ identifier: String) -> Bool {
        let parts = identifier.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        return isValidIdentifier(String(parts[0])) && isValidIdentifier(String(parts[1]))
    }

    public static func validate(_ ruleset: Ruleset) -> [String] {
        var errors: [String] = []

        if ruleset.rulesetVersion < 1 {
            errors.append("rulesetVersion is not a positive integer")
        }
        if ruleset.sites.isEmpty {
            errors.append("sites is not a non empty array")
            return errors
        }

        var seenSiteIDs: Set<String> = []
        var seenFeatureIDs: Set<String> = []

        for (siteIndex, site) in ruleset.sites.enumerated() {
            let where_ = "sites[\(siteIndex)]"

            if !isValidIdentifier(site.id) {
                errors.append("\(where_).id is missing or malformed")
            }
            if seenSiteIDs.contains(site.id) {
                errors.append("\(where_).id is a duplicate: \(site.id)")
            }
            seenSiteIDs.insert(site.id)

            if site.name.isEmpty {
                errors.append("\(where_).name is missing")
            }
            if site.matches.isEmpty {
                errors.append("\(where_).matches is not a non empty array")
            }
            for (index, pattern) in site.matches.enumerated() where MatchPattern(pattern) == nil {
                errors.append("\(where_).matches[\(index)] is not a valid match pattern: \(pattern)")
            }
            if site.features.isEmpty {
                errors.append("\(where_).features is not a non empty array")
                continue
            }

            for (featureIndex, feature) in site.features.enumerated() {
                let at = "\(where_).features[\(featureIndex)]"

                if !isValidFeatureIdentifier(feature.id) {
                    errors.append("\(at).id is missing or malformed")
                } else if !feature.id.hasPrefix(site.id + ".") {
                    errors.append("\(at).id must be namespaced under its site: \(feature.id)")
                }
                if seenFeatureIDs.contains(feature.id) {
                    errors.append("\(at).id is a duplicate: \(feature.id)")
                }
                seenFeatureIDs.insert(feature.id)

                if feature.name.isEmpty {
                    errors.append("\(at).name is missing")
                }
                if feature.hide.isEmpty {
                    errors.append("\(at).hide is not a non empty array")
                }
                for (index, selector) in feature.hide.enumerated() where !isSafeSelector(selector) {
                    errors.append("\(at).hide[\(index)] is unsafe or empty: \(selector)")
                }
                for (index, selector) in (feature.verify ?? []).enumerated() where !isSafeSelector(selector) {
                    errors.append("\(at).verify[\(index)] is unsafe or empty: \(selector)")
                }
                if let appliesTo = feature.appliesTo {
                    if appliesTo.isEmpty {
                        errors.append("\(at).appliesTo is present but not a non empty array")
                    }
                    for (index, glob) in appliesTo.enumerated() where glob.isEmpty {
                        errors.append("\(at).appliesTo[\(index)] is not a non empty string")
                    }
                }
            }
        }

        return errors
    }

    public static func isValid(_ ruleset: Ruleset) -> Bool {
        validate(ruleset).isEmpty
    }
}
