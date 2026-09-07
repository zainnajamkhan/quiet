//
//  BlockPolicy.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

public struct BlockedApplication: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// What the user wants blocked and when. Blocking is off unless something makes it on:
/// either a schedule that is currently active, or a manually started session. An empty
/// policy blocks nothing, which is the correct resting state for an app people install and
/// then configure gradually.
public struct BlockPolicy: Codable, Equatable, Sendable {
    public let blockedApplications: [BlockedApplication]
    public let blockedHosts: [HostPattern]
    public let schedules: [Schedule]

    public init(
        blockedApplications: [BlockedApplication] = [],
        blockedHosts: [HostPattern] = [],
        schedules: [Schedule] = []
    ) {
        self.blockedApplications = blockedApplications
        self.blockedHosts = blockedHosts
        self.schedules = schedules
    }

    public static let empty = BlockPolicy()

    private enum CodingKeys: String, CodingKey {
        case blockedApplications
        case blockedHosts
        case schedules
    }

    /// Tolerates every shape this file has had, so an app update never starts by throwing
    /// away the blocklist the user already built. Unknown keys, such as the focusProfiles
    /// written by the build where Focus mode briefly existed, are ignored rather than fatal.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blockedApplications = try container.decodeIfPresent([BlockedApplication].self, forKey: .blockedApplications) ?? []
        blockedHosts = try container.decodeIfPresent([HostPattern].self, forKey: .blockedHosts) ?? []
        schedules = try container.decodeIfPresent([Schedule].self, forKey: .schedules) ?? []
    }

    /// Copies the policy with only the named fields replaced. Every field is stored `let`,
    /// so without this each edit has to restate all of them, and the failure mode of
    /// forgetting one is silent data loss rather than a compiler error.
    public func with(
        blockedApplications: [BlockedApplication]? = nil,
        blockedHosts: [HostPattern]? = nil,
        schedules: [Schedule]? = nil
    ) -> BlockPolicy {
        BlockPolicy(
            blockedApplications: blockedApplications ?? self.blockedApplications,
            blockedHosts: blockedHosts ?? self.blockedHosts,
            schedules: schedules ?? self.schedules
        )
    }

    /// True when something in the policy blocks regardless of the clock.
    public var blocksAlways: Bool {
        schedules.contains { $0.kind == .always && $0.enabled }
    }

    /// Turns blocking on or off wholesale. Blocking is only ever active because a schedule
    /// says so, so an empty schedule list is the correct "configured but not blocking"
    /// state rather than a bug.
    public func settingBlocksAlways(_ blocksAlways: Bool) -> BlockPolicy {
        let others = schedules.filter { $0.kind != .always }
        let always = blocksAlways ? [Schedule(id: "always", kind: .always, enabled: true)] : []
        return with(schedules: others + always)
    }
}

public enum BlockEvaluator {

    /// Blocking is active when a manual session is running, or when any enabled schedule
    /// says so. Both are checked because they answer different questions: a session is
    /// "I chose to start focusing now", a schedule is "this is always true on Tuesday
    /// mornings".
    public static func isBlockingActive(
        policy: BlockPolicy,
        session: BlockSession?,
        now: Date,
        moment: ScheduleMoment,
        activeFocusIdentifiers: [String] = []
    ) -> Bool {
        if let session, session.isActive(asOf: now) { return true }
        return policy.schedules.contains { schedule in
            ScheduleEvaluator.isActive(schedule, at: moment, activeFocusIdentifiers: activeFocusIdentifiers)
        }
    }

    public static func isApplicationBlocked(
        bundleIdentifier: String,
        policy: BlockPolicy,
        session: BlockSession?,
        now: Date,
        moment: ScheduleMoment,
        activeFocusIdentifiers: [String] = []
    ) -> Bool {
        guard !bundleIdentifier.isEmpty else { return false }
        guard policy.blockedApplications.contains(where: { $0.id == bundleIdentifier }) else { return false }
        return isBlockingActive(
            policy: policy,
            session: session,
            now: now,
            moment: moment,
            activeFocusIdentifiers: activeFocusIdentifiers
        )
    }

    public static func isHostBlocked(
        _ host: String,
        policy: BlockPolicy,
        session: BlockSession?,
        now: Date,
        moment: ScheduleMoment,
        activeFocusIdentifiers: [String] = []
    ) -> Bool {
        guard policy.blockedHosts.contains(where: { $0.matches(host: host) }) else { return false }
        return isBlockingActive(
            policy: policy,
            session: session,
            now: now,
            moment: moment,
            activeFocusIdentifiers: activeFocusIdentifiers
        )
    }

    /// The hosts the Safari extension should currently refuse, flattened for handing across
    /// the app/extension boundary. Empty when nothing is active, so the extension never has
    /// to understand schedules or sessions itself.
    public static func currentlyBlockedHosts(
        policy: BlockPolicy,
        session: BlockSession?,
        now: Date,
        moment: ScheduleMoment,
        activeFocusIdentifiers: [String] = []
    ) -> [String] {
        guard isBlockingActive(
            policy: policy,
            session: session,
            now: now,
            moment: moment,
            activeFocusIdentifiers: activeFocusIdentifiers
        ) else { return [] }
        return policy.blockedHosts.map(\.domain)
    }
}
