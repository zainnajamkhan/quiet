//
//  RulesetSelection.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

public enum RulesetSelection {

    public enum Source: String, Equatable, Sendable {
        case bundled
        case remote
        case none
    }

    public struct Outcome: Equatable, Sendable {
        public let ruleset: Ruleset?
        public let source: Source
        public let reason: String
    }

    /// The bundled ruleset wins unless the remote one is valid, speaks the same schema and
    /// carries a higher `rulesetVersion`. Every failure falls back rather than throwing, so a
    /// bad publish can never take the extension offline.
    public static func choose(bundled: Ruleset, remote: Ruleset?) -> Outcome {
        let bundledErrors = validate(bundled)
        if let first = bundledErrors.first {
            return Outcome(ruleset: nil, source: .none, reason: "bundled ruleset is invalid: \(first)")
        }
        if bundled.schemaVersion != Ruleset.supportedSchemaVersion {
            return Outcome(ruleset: nil, source: .none, reason: "bundled ruleset schemaVersion is not supported")
        }
        guard let remote else {
            return Outcome(ruleset: bundled, source: .bundled, reason: "no remote ruleset")
        }
        if let first = validate(remote).first {
            return Outcome(ruleset: bundled, source: .bundled, reason: "remote ruleset is invalid: \(first)")
        }
        if remote.schemaVersion != Ruleset.supportedSchemaVersion {
            return Outcome(
                ruleset: bundled,
                source: .bundled,
                reason: "remote ruleset needs schema \(remote.schemaVersion)"
            )
        }
        if remote.rulesetVersion <= bundled.rulesetVersion {
            return Outcome(ruleset: bundled, source: .bundled, reason: "remote ruleset is not newer")
        }
        return Outcome(
            ruleset: remote,
            source: .remote,
            reason: "remote ruleset version \(remote.rulesetVersion)"
        )
    }

    private static func validate(_ ruleset: Ruleset) -> [String] {
        RulesetValidator.validate(ruleset)
    }
}
