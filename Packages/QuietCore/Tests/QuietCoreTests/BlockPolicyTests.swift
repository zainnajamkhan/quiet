//
//  BlockPolicyTests.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Testing
@testable import QuietCore

private let reference = Date(timeIntervalSince1970: 1_800_000_000)
private let wednesdayMidday = ScheduleMoment(weekday: 4, minutesSinceMidnight: 720)

private func policy(
    apps: [String] = [],
    hosts: [String] = [],
    schedules: [Schedule] = []
) -> BlockPolicy {
    BlockPolicy(
        blockedApplications: apps.map { BlockedApplication(id: $0, name: $0) },
        blockedHosts: hosts.compactMap { HostPattern($0) },
        schedules: schedules
    )
}

private let alwaysOn = Schedule(id: "always", kind: .always, enabled: true)
private let alwaysOff = Schedule(id: "off", kind: .always, enabled: false)
private let workHours = Schedule(
    id: "work",
    kind: .window,
    enabled: true,
    windows: [ScheduleWindow(days: [2, 3, 4, 5, 6], start: "09:00", end: "17:00")]
)

// MARK: - Nothing is blocked by default

@Test func anEmptyPolicyBlocksNothing() {
    #expect(!BlockEvaluator.isApplicationBlocked(
        bundleIdentifier: "com.apple.Safari", policy: .empty, session: nil,
        now: reference, moment: wednesdayMidday
    ))
    #expect(!BlockEvaluator.isHostBlocked(
        "youtube.com", policy: .empty, session: nil, now: reference, moment: wednesdayMidday
    ))
    #expect(BlockEvaluator.currentlyBlockedHosts(
        policy: .empty, session: nil, now: reference, moment: wednesdayMidday
    ).isEmpty)
}

@Test func aBlockListWithNoScheduleAndNoSessionBlocksNothing() {
    // The list says what could be blocked; a schedule or session says when. Neither here.
    let p = policy(apps: ["com.tinyspeck.slackmacgap"], hosts: ["youtube.com"])
    #expect(!BlockEvaluator.isApplicationBlocked(
        bundleIdentifier: "com.tinyspeck.slackmacgap", policy: p, session: nil,
        now: reference, moment: wednesdayMidday
    ))
    #expect(!BlockEvaluator.isHostBlocked(
        "youtube.com", policy: p, session: nil, now: reference, moment: wednesdayMidday
    ))
}

// MARK: - Schedules

@Test func anAlwaysOnScheduleBlocksListedItemsOnly() {
    let p = policy(apps: ["com.tinyspeck.slackmacgap"], hosts: ["youtube.com"], schedules: [alwaysOn])

    #expect(BlockEvaluator.isApplicationBlocked(
        bundleIdentifier: "com.tinyspeck.slackmacgap", policy: p, session: nil,
        now: reference, moment: wednesdayMidday
    ))
    #expect(!BlockEvaluator.isApplicationBlocked(
        bundleIdentifier: "com.apple.Terminal", policy: p, session: nil,
        now: reference, moment: wednesdayMidday
    ), "an app that is not on the list is never blocked")

    #expect(BlockEvaluator.isHostBlocked("youtube.com", policy: p, session: nil, now: reference, moment: wednesdayMidday))
    #expect(!BlockEvaluator.isHostBlocked("wikipedia.org", policy: p, session: nil, now: reference, moment: wednesdayMidday))
}

@Test func aDisabledScheduleDoesNotBlock() {
    let p = policy(apps: ["com.a.b"], schedules: [alwaysOff])
    #expect(!BlockEvaluator.isApplicationBlocked(
        bundleIdentifier: "com.a.b", policy: p, session: nil, now: reference, moment: wednesdayMidday
    ))
}

@Test func aWindowScheduleBlocksOnlyInsideItsWindow() {
    let p = policy(apps: ["com.a.b"], schedules: [workHours])

    let insideHours = ScheduleMoment(weekday: 4, minutesSinceMidnight: 600)
    let outsideHours = ScheduleMoment(weekday: 4, minutesSinceMidnight: 1200)
    let weekend = ScheduleMoment(weekday: 7, minutesSinceMidnight: 600)

    #expect(BlockEvaluator.isApplicationBlocked(bundleIdentifier: "com.a.b", policy: p, session: nil, now: reference, moment: insideHours))
    #expect(!BlockEvaluator.isApplicationBlocked(bundleIdentifier: "com.a.b", policy: p, session: nil, now: reference, moment: outsideHours))
    #expect(!BlockEvaluator.isApplicationBlocked(bundleIdentifier: "com.a.b", policy: p, session: nil, now: reference, moment: weekend))
}

@Test func anyOneActiveScheduleIsEnough() {
    let p = policy(apps: ["com.a.b"], schedules: [alwaysOff, workHours])
    let insideHours = ScheduleMoment(weekday: 4, minutesSinceMidnight: 600)
    #expect(BlockEvaluator.isApplicationBlocked(bundleIdentifier: "com.a.b", policy: p, session: nil, now: reference, moment: insideHours))
}

// MARK: - Sessions

@Test func anActiveSessionBlocksEvenWithNoSchedule() {
    let p = policy(apps: ["com.a.b"], hosts: ["youtube.com"])
    let session = BlockSession(startedAt: reference, duration: 3600, isStrict: false)

    #expect(BlockEvaluator.isApplicationBlocked(
        bundleIdentifier: "com.a.b", policy: p, session: session,
        now: reference.addingTimeInterval(600), moment: wednesdayMidday
    ))
    #expect(BlockEvaluator.isHostBlocked(
        "youtube.com", policy: p, session: session,
        now: reference.addingTimeInterval(600), moment: wednesdayMidday
    ))
}

@Test func anExpiredSessionStopsBlocking() {
    let p = policy(apps: ["com.a.b"])
    let session = BlockSession(startedAt: reference, duration: 3600, isStrict: false)
    #expect(!BlockEvaluator.isApplicationBlocked(
        bundleIdentifier: "com.a.b", policy: p, session: session,
        now: session.endsAt, moment: wednesdayMidday
    ))
}

@Test func aSessionAndAScheduleAreIndependentReasonsToBlock() {
    let p = policy(apps: ["com.a.b"], schedules: [workHours])
    let expiredSession = BlockSession(startedAt: reference, duration: 60, isStrict: false)
    let insideHours = ScheduleMoment(weekday: 4, minutesSinceMidnight: 600)

    #expect(BlockEvaluator.isApplicationBlocked(
        bundleIdentifier: "com.a.b", policy: p, session: expiredSession,
        now: reference.addingTimeInterval(999), moment: insideHours
    ), "the schedule still blocks even though the session has ended")
}

// MARK: - Host matching and the flattened list for the extension

@Test func hostBlockingCoversSubdomainsButNotLookalikes() {
    let p = policy(hosts: ["reddit.com"], schedules: [alwaysOn])
    #expect(BlockEvaluator.isHostBlocked("old.reddit.com", policy: p, session: nil, now: reference, moment: wednesdayMidday))
    #expect(!BlockEvaluator.isHostBlocked("notreddit.com", policy: p, session: nil, now: reference, moment: wednesdayMidday))
}

@Test func currentlyBlockedHostsIsEmptyWhenNothingIsActive() {
    let p = policy(hosts: ["youtube.com", "reddit.com"])
    #expect(BlockEvaluator.currentlyBlockedHosts(policy: p, session: nil, now: reference, moment: wednesdayMidday).isEmpty)
}

@Test func currentlyBlockedHostsListsNormalisedDomainsWhenActive() {
    let p = policy(hosts: ["https://www.YouTube.com/feed", "reddit.com"], schedules: [alwaysOn])
    let hosts = BlockEvaluator.currentlyBlockedHosts(policy: p, session: nil, now: reference, moment: wednesdayMidday)
    #expect(hosts.sorted() == ["reddit.com", "youtube.com"])
}

@Test func anEmptyBundleIdentifierIsNeverBlocked() {
    let p = policy(apps: [""], schedules: [alwaysOn])
    #expect(!BlockEvaluator.isApplicationBlocked(
        bundleIdentifier: "", policy: p, session: nil, now: reference, moment: wednesdayMidday
    ))
}

@Test func policyRoundTripsThroughCoding() throws {
    let p = policy(apps: ["com.a.b"], hosts: ["youtube.com"], schedules: [workHours])
    let decoded = try JSONDecoder().decode(BlockPolicy.self, from: JSONEncoder().encode(p))
    #expect(decoded == p)
}

@Test func policyStoreRoundTripsThroughARealFile() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("block-policy.json")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    let saved = policy(apps: ["com.a.b"], hosts: ["youtube.com"], schedules: [alwaysOn])
    try BlockPolicyStore.save(saved, to: url)
    #expect(BlockPolicyStore.load(from: url) == saved)
}

@Test func policyStoreReturnsEmptyForMissingOrCorruptFiles() throws {
    let missing = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("nope.json")
    #expect(BlockPolicyStore.load(from: missing) == .empty)

    let corrupt = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("block-policy.json")
    defer { try? FileManager.default.removeItem(at: corrupt.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(at: corrupt.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("garbage".utf8).write(to: corrupt)
    #expect(BlockPolicyStore.load(from: corrupt) == .empty)
}
