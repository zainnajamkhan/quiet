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
