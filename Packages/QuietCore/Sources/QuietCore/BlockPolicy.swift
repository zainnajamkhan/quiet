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

    /// Focus links the user has created. Separate from `schedules` because a profile is a
    /// name the user recognises in System Settings, while the schedule it implies is
    /// derived (see `FocusPolicy.schedules(for:)`).
    public let focusProfiles: [FocusProfile]

    public init(
        blockedApplications: [BlockedApplication] = [],
        blockedHosts: [HostPattern] = [],
        schedules: [Schedule] = [],
        focusProfiles: [FocusProfile] = []
    ) {
        self.blockedApplications = blockedApplications
        self.blockedHosts = blockedHosts
        self.schedules = schedules
        self.focusProfiles = focusProfiles
    }

    public static let empty = BlockPolicy()

    private enum CodingKeys: String, CodingKey {
        case blockedApplications
        case blockedHosts
        case schedules
        case focusProfiles
    }

    /// Decodes files written before Focus links existed, so an app update never starts by
    /// throwing away the blocklist the user already built.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blockedApplications = try container.decodeIfPresent([BlockedApplication].self, forKey: .blockedApplications) ?? []
        blockedHosts = try container.decodeIfPresent([HostPattern].self, forKey: .blockedHosts) ?? []
        schedules = try container.decodeIfPresent([Schedule].self, forKey: .schedules) ?? []
        focusProfiles = try container.decodeIfPresent([FocusProfile].self, forKey: .focusProfiles) ?? []
    }

    /// Copies the policy with only the named fields replaced. Every field is stored `let`,
    /// so without this each edit has to restate all four, and the failure mode of
    /// forgetting one is silent data loss rather than a compiler error.
    public func with(
        blockedApplications: [BlockedApplication]? = nil,
        blockedHosts: [HostPattern]? = nil,
        schedules: [Schedule]? = nil,
        focusProfiles: [FocusProfile]? = nil
    ) -> BlockPolicy {
        BlockPolicy(
            blockedApplications: blockedApplications ?? self.blockedApplications,
            blockedHosts: blockedHosts ?? self.blockedHosts,
            schedules: schedules ?? self.schedules,
            focusProfiles: focusProfiles ?? self.focusProfiles
        )
    }

    /// True when something in the policy blocks regardless of the clock or any Focus.
    public var blocksAlways: Bool {
        schedules.contains { $0.kind == .always && $0.enabled }
    }

    /// Replaces the Focus links and rebuilds the schedules they imply, leaving any
    /// non Focus schedule (always on, time windows) untouched.
    public func settingFocusProfiles(_ profiles: [FocusProfile]) -> BlockPolicy {
        let others = schedules.filter { $0.kind != .focus }
        return with(
            schedules: others + FocusPolicy.schedules(for: profiles),
            focusProfiles: profiles
        )
    }

    /// Switches between "block all the time" and "block only while a Focus is on". These
    /// are mutually exclusive on purpose: an always on schedule would sit alongside the
    /// Focus schedules and quietly make them irrelevant.
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
