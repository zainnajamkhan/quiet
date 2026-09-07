//
//  RulesetUpdate.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// What Quiet knows about remote rule updates, persisted between launches.
///
/// The ruleset is kept alongside the bookkeeping rather than in a separate file so a check
/// can never half succeed: either the whole record is replaced or none of it is.
public struct RulesetUpdateState: Codable, Equatable, Sendable {

    /// The most recent remote ruleset that passed validation and was newer than the one in
    /// the app bundle. Nil means "nothing has ever been accepted", which is the normal
    /// state for a fresh install and for anyone offline.
    public let ruleset: Ruleset?
    public let lastCheckedAt: Date?

    /// Plain language result of the last check, for the UI. Kept as text because the only
    /// consumer is a person reading it, and inventing an error enum would mean translating
    /// it straight back into prose.
    public let lastResult: String?

    public init(ruleset: Ruleset? = nil, lastCheckedAt: Date? = nil, lastResult: String? = nil) {
        self.ruleset = ruleset
        self.lastCheckedAt = lastCheckedAt
        self.lastResult = lastResult
    }

    public static let empty = RulesetUpdateState()
}

public enum RulesetUpdateOutcome: Equatable, Sendable {
    /// A newer, valid ruleset was fetched and should replace what is stored.
    case adopted(Ruleset)
    /// Something was fetched but must not be used. Carries the reason, which is worth
    /// surfacing: it usually means a bad publish rather than a bad network.
    case rejected(String)
    /// Nothing to do. Already up to date, or nothing published.
    case unchanged(String)

    public var reason: String {
        switch self {
        case .adopted(let ruleset): "Updated to rules version \(ruleset.rulesetVersion)"
        case .rejected(let reason): reason
        case .unchanged(let reason): reason
        }
    }
}

/// Decides when to check and what to do with what comes back.
///
/// Deliberately pure and separate from the thing that does the fetching. The network part
/// cannot be exercised without a paid developer account and a published record, so every
/// decision that could silently break rule delivery lives here instead, where it is a unit
/// test rather than something discovered when selectors rot in six months.
public enum RulesetUpdatePolicy {

    /// Rules are reviewed weekly, so checking daily is already far more often than they can
    /// change. Anything faster spends the user's battery to learn nothing.
    public static let checkInterval: TimeInterval = 24 * 60 * 60

    /// A first run has never checked, so it checks immediately. A clock moved backwards
    /// makes the last check appear to be in the future, which must not disable updates
    /// forever, so that also reads as due.
    public static func isCheckDue(
        lastCheckedAt: Date?,
        now: Date,
        interval: TimeInterval = checkInterval
    ) -> Bool {
        guard let lastCheckedAt else { return true }
        let elapsed = now.timeIntervalSince(lastCheckedAt)
        if elapsed < 0 { return true }
        return elapsed >= interval
    }

    /// Applies the same rules the extension applies at read time, at write time, so a bad
    /// publish is discarded once here rather than being re-evaluated on every page load.
    public static func evaluate(
        candidate: Ruleset?,
        bundled: Ruleset,
        stored: Ruleset?
    ) -> RulesetUpdateOutcome {
        guard let candidate else {
            return .unchanged("No rules have been published yet")
        }

        let outcome = RulesetSelection.choose(bundled: bundled, remote: candidate)
        guard outcome.source == .remote else {
            // choose() falls back for two different reasons: the candidate is broken, or it
            // is simply not newer than what shipped. Only the first is worth alarming about.
            return outcome.reason.contains("not newer")
                ? .unchanged("Already up to date")
                : .rejected(outcome.reason)
        }

        if let stored, candidate.rulesetVersion <= stored.rulesetVersion {
            return .unchanged("Already up to date")
        }

        return .adopted(candidate)
    }

    /// Folds an outcome into the stored state. A rejected or unchanged result still records
    /// the check, so a broken publish does not cause Quiet to retry in a tight loop.
    public static func apply(
        _ outcome: RulesetUpdateOutcome,
        to state: RulesetUpdateState,
        now: Date
    ) -> RulesetUpdateState {
        switch outcome {
        case .adopted(let ruleset):
            return RulesetUpdateState(ruleset: ruleset, lastCheckedAt: now, lastResult: outcome.reason)
        case .rejected, .unchanged:
            return RulesetUpdateState(ruleset: state.ruleset, lastCheckedAt: now, lastResult: outcome.reason)
        }
    }
}

/// Persists the update state in the App Group, so the Safari extension can be handed the
/// accepted ruleset without needing any network access of its own.
public enum RulesetUpdateStore {

    public static func fileURL() -> URL {
        SharedStateStore.fileURL().deletingLastPathComponent().appendingPathComponent("ruleset-update.json")
    }

    public static func load(from url: URL = fileURL()) -> RulesetUpdateState {
        guard let data = try? Data(contentsOf: url) else { return .empty }
        return (try? JSONDecoder().decode(RulesetUpdateState.self, from: data)) ?? .empty
    }

    public static func save(_ state: RulesetUpdateState, to url: URL = fileURL()) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
}
