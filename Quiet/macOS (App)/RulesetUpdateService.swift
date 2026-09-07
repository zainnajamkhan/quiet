//
//  RulesetUpdateService.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import CloudKit
import Combine
import Foundation
import QuietCore
import os.log

/// Where a newer ruleset comes from. A protocol so the decision logic in
/// `RulesetUpdatePolicy` can be tested exhaustively without a network, and so the delivery
/// mechanism can change without touching anything that decides what is safe to install.
protocol RulesetSource: Sendable {
    var describedSource: String { get }
    func fetchLatest() async throws -> Ruleset?
}

/// Apple hosted, no server to run, and updates reach users without waiting on App Review.
///
/// **Not active yet.** CloudKit needs the iCloud entitlement, which needs a paid Apple
/// Developer Program membership, so `containerIdentifier` is deliberately nil. Leave it nil
/// until the entitlement is really present: `CKContainer(identifier:)` raises an exception
/// for a container the app is not entitled to, which would crash on launch rather than
/// degrade, so the nil check below is load bearing and not defensive noise.
struct CloudKitRulesetSource: RulesetSource {

    static let containerIdentifier: String? = nil

    static let recordType = "Ruleset"

    let containerIdentifier: String

    var describedSource: String { "iCloud" }

    func fetchLatest() async throws -> Ruleset? {
        let database = CKContainer(identifier: containerIdentifier).publicCloudDatabase
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "rulesetVersion", ascending: false)]

        let (matches, _) = try await database.records(matching: query, resultsLimit: 1)
        guard let record = try matches.first?.1.get() else { return nil }

        // The payload travels as an asset rather than a string field: a ruleset covering
        // every supported site will outgrow what belongs in a record field, and an asset
        // costs nothing extra here.
        guard let asset = record["payload"] as? CKAsset, let fileURL = asset.fileURL else {
            return nil
        }
        return try Ruleset.decode(from: try Data(contentsOf: fileURL))
    }
}

/// A plain signed HTTPS fetch of the same JSON.
///
/// Present because it is the only delivery path that can be exercised without a paid
/// membership, so the whole pipeline around it is real and testable today rather than
/// waiting on an account. Swapping to CloudKit later is one line in `makeSource`.
struct HTTPRulesetSource: RulesetSource {

    static let url: URL? = nil

    let url: URL

    var describedSource: String { url.host ?? "the web" }

    func fetchLatest() async throws -> Ruleset? {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try Ruleset.decode(from: data)
    }
}

/// Fetches, validates and stores rule updates.
///
/// The valuable part of this file is what it refuses to do. Every failure leaves the last
/// good ruleset in place and the app keeps working on whatever shipped in the bundle, so a
/// bad publish, an expired certificate or a plane with no wifi are all the same
/// non event. `RulesetUpdatePolicy` owns those decisions and is unit tested; this type only
/// moves bytes and reports.
@MainActor
final class RulesetUpdateService: ObservableObject {

    @Published private(set) var state: RulesetUpdateState
    @Published private(set) var isChecking = false

    private let bundled: Ruleset?
    private let source: RulesetSource?

    init(bundled: Ruleset?, source: RulesetSource? = nil) {
        self.bundled = bundled
        self.source = source ?? Self.makeSource()
        self.state = RulesetUpdateStore.load()
    }

    /// Nil when no delivery mechanism is configured, which is the current shipping state.
    /// Quiet then runs entirely on its bundled rules, which is exactly what it does today.
    nonisolated static func makeSource() -> RulesetSource? {
        if let identifier = CloudKitRulesetSource.containerIdentifier {
            return CloudKitRulesetSource(containerIdentifier: identifier)
        }
        if let url = HTTPRulesetSource.url {
            return HTTPRulesetSource(url: url)
        }
        return nil
    }

    var isConfigured: Bool { source != nil }

    /// The ruleset the extension should actually be using, which is the accepted remote one
    /// if there is one and the bundled one otherwise.
    var effectiveRulesetVersion: Int? {
        state.ruleset?.rulesetVersion ?? bundled?.rulesetVersion
    }

    func checkIfDue(now: Date = Date()) async {
        guard RulesetUpdatePolicy.isCheckDue(lastCheckedAt: state.lastCheckedAt, now: now) else { return }
        await check(now: now)
    }

    func check(now: Date = Date()) async {
        guard let bundled, let source, !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        let candidate: Ruleset?
        do {
            candidate = try await source.fetchLatest()
        } catch {
            // A failed fetch is not a failed check in any sense the user cares about: the
            // rules they have keep working. Record it and move on.
            os_log(.default, "Quiet: rule update fetch failed: %{public}@", String(describing: error))
            persist(RulesetUpdatePolicy.apply(
                .unchanged("Could not reach \(source.describedSource)"),
                to: state,
                now: now
            ))
            return
        }

        let outcome = RulesetUpdatePolicy.evaluate(
            candidate: candidate,
            bundled: bundled,
            stored: state.ruleset
        )
        if case .rejected(let reason) = outcome {
            os_log(.default, "Quiet: rejected a published ruleset: %{public}@", reason)
        }
        persist(RulesetUpdatePolicy.apply(outcome, to: state, now: now))
    }

    private func persist(_ newState: RulesetUpdateState) {
        state = newState
        try? RulesetUpdateStore.save(newState)
    }
}
