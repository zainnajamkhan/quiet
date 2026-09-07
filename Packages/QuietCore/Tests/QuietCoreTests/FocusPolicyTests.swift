//
//  FocusPolicyTests.swift
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

// MARK: - Naming

@Test(arguments: [
    ("Work", "work"),
    ("Work Mode", "work-mode"),
    ("  Deep   Work  ", "deep-work"),
    ("WORK", "work"),
    ("Work/Life", "work-life"),
    ("Focus 2", "focus-2"),
    ("---Work---", "work"),
    ("Do Not Disturb", "do-not-disturb"),
])
func namesThatDifferOnlyCosmeticallyProduceTheSameIdentifier(name: String, expected: String) {
    #expect(FocusPolicy.slug(from: name) == expected)
}

@Test(arguments: ["", "   ", "!!!", "...", "😀", "---"])
func namesWithNothingToIdentifyAreRejected(name: String) {
    #expect(FocusPolicy.slug(from: name) == nil)
    #expect(FocusPolicy.makeProfile(name: name, existing: []) == nil)
}

@Test func aProfileKeepsTheNameTheUserTypedAndTrimsOnlyTheEdges() {
    let profile = FocusPolicy.makeProfile(name: "  Deep Work  ", existing: [])
    #expect(profile?.name == "Deep Work")
    #expect(profile?.id == "deep-work")
}

@Test func aRepeatedNameGetsItsOwnIdentifierRatherThanMergingIntoTheFirst() {
    let first = FocusPolicy.makeProfile(name: "Work", existing: [])
    let second = FocusPolicy.makeProfile(name: "Work", existing: [first!])
    let third = FocusPolicy.makeProfile(name: "work", existing: [first!, second!])

    #expect(first?.id == "work")
    #expect(second?.id == "work-2")
    #expect(third?.id == "work-3")
    #expect(Set([first!.id, second!.id, third!.id]).count == 3)
}

@Test func aUserSuppliedNameCanNeverCollideWithTheAnyFocusWildcard() {
    // The wildcard is "*", and slugging only emits a-z, 0-9 and "-", so this holds by
    // construction. Asserted anyway because the whole Focus feature silently breaks if a
    // profile ever claims the wildcard identifier.
    for name in ["*", "Any Focus", "star", "**", "any"] {
        let profile = FocusPolicy.makeProfile(name: name, existing: [])
        #expect(profile?.id != FocusPolicy.anyFocusIdentifier)
    }
    #expect(FocusPolicy.anyFocus.id == ScheduleEvaluator.focusWildcard)
}

// MARK: - Derived schedules

@Test func eachProfileBecomesOneEnabledFocusSchedule() {
    let profiles = [FocusProfile(id: "work", name: "Work"), FocusProfile(id: "study", name: "Study")]
    let schedules = FocusPolicy.schedules(for: profiles)

    #expect(schedules.count == 2)
    #expect(schedules.allSatisfy { $0.kind == .focus && $0.enabled })
    #expect(schedules.map(\.id) == ["focus-work", "focus-study"])
    #expect(schedules.map { $0.focusIdentifiers ?? [] } == [["work"], ["study"]])
}

@Test func removingAProfileRemovesTheScheduleItImplied() {
    // The bug this guards against: a leftover focus schedule keeps blocking forever
    // because nothing can ever deactivate an identifier the user can no longer see.
    let work = FocusProfile(id: "work", name: "Work")
    let study = FocusProfile(id: "study", name: "Study")
    let policy = BlockPolicy.empty.settingFocusProfiles([work, study])
    let reduced = policy.settingFocusProfiles([work])

    #expect(reduced.focusProfiles == [work])
    #expect(reduced.schedules.map(\.id) == ["focus-work"])
}

@Test func settingFocusProfilesLeavesNonFocusSchedulesAlone() {
    let window = Schedule(
        id: "mornings", kind: .window, enabled: true,
        windows: [ScheduleWindow(days: [2], start: "09:00", end: "12:00")]
    )
    let policy = BlockPolicy(schedules: [window]).settingFocusProfiles([FocusProfile(id: "work", name: "Work")])

    #expect(policy.schedules.contains(window))
    #expect(policy.schedules.count == 2)
}

@Test func everyGeneratedFocusScheduleSurvivesTheScheduleValidator() {
    // The schedule engine silently evaluates an invalid schedule as "not active", so a
    // malformed generated id does not throw: it just means Focus mode never blocks
    // anything. Identifiers are validated against [a-z0-9]+(-[a-z0-9]+)*, which is why
    // the wildcard profile cannot simply be interpolated into its schedule id.
    let profiles = [
        FocusPolicy.anyFocus,
        FocusPolicy.makeProfile(name: "Work", existing: [])!,
        FocusPolicy.makeProfile(name: "Deep Work / Study", existing: [])!,
        FocusPolicy.makeProfile(name: "Focus 2", existing: [])!,
        FocusPolicy.makeProfile(name: "Work", existing: [FocusProfile(id: "work", name: "Work")])!,
    ]
    for schedule in FocusPolicy.schedules(for: profiles) {
        #expect(ScheduleValidator.validate(schedule) == [], "\(schedule.id) is not a valid schedule")
    }
}

@Test func theWildcardScheduleIdCannotBeClaimedByANamedProfile() {
    #expect(FocusPolicy.scheduleIdentifier(for: FocusPolicy.anyFocusIdentifier) == "focus")
    for name in ["Focus", "focus", "  Focus  "] {
        let profile = FocusPolicy.makeProfile(name: name, existing: [])!
        #expect(FocusPolicy.scheduleIdentifier(for: profile.id) != "focus")
    }
}

// MARK: - Always versus during a Focus

@Test func alwaysAndDuringFocusAreMutuallyExclusive() {
    // An always-on schedule sitting next to the focus schedules would make them
    // meaningless, which reads to the user as "Focus mode does nothing".
    let policy = BlockPolicy.empty
        .settingFocusProfiles([FocusProfile(id: "work", name: "Work")])
        .settingBlocksAlways(true)
    #expect(policy.blocksAlways)

    let focusOnly = policy.settingBlocksAlways(false)
    #expect(!focusOnly.blocksAlways)
    #expect(focusOnly.schedules.map(\.id) == ["focus-work"])
    #expect(focusOnly.focusProfiles.count == 1)
}

@Test func switchingBackAndForthDoesNotAccumulateSchedules() {
    var policy = BlockPolicy.empty.settingFocusProfiles([FocusProfile(id: "work", name: "Work")])
    for _ in 0..<5 {
        policy = policy.settingBlocksAlways(true).settingBlocksAlways(false).settingBlocksAlways(true)
    }
    #expect(policy.schedules.filter { $0.kind == .always }.count == 1)
    #expect(policy.schedules.filter { $0.kind == .focus }.count == 1)
}

// MARK: - End to end through the evaluator

private func focusPolicy(hosts: [String], profiles: [FocusProfile]) -> BlockPolicy {
    BlockPolicy(blockedHosts: hosts.compactMap { HostPattern($0) }).settingFocusProfiles(profiles)
}

@Test func aFocusPolicyBlocksNothingWhileNoFocusIsRunning() {
    let policy = focusPolicy(hosts: ["youtube.com"], profiles: [FocusProfile(id: "work", name: "Work")])
    #expect(!BlockEvaluator.isHostBlocked(
        "youtube.com", policy: policy, session: nil, now: reference,
        moment: wednesdayMidday, activeFocusIdentifiers: []
    ))
    #expect(BlockEvaluator.currentlyBlockedHosts(
        policy: policy, session: nil, now: reference,
        moment: wednesdayMidday, activeFocusIdentifiers: []
    ).isEmpty)
}

@Test func aFocusPolicyBlocksWhileItsOwnFocusIsRunning() {
    let policy = focusPolicy(hosts: ["youtube.com"], profiles: [FocusProfile(id: "work", name: "Work")])
    #expect(BlockEvaluator.isHostBlocked(
        "youtube.com", policy: policy, session: nil, now: reference,
        moment: wednesdayMidday, activeFocusIdentifiers: ["work"]
    ))
    #expect(BlockEvaluator.currentlyBlockedHosts(
        policy: policy, session: nil, now: reference,
        moment: wednesdayMidday, activeFocusIdentifiers: ["work"]
    ) == ["youtube.com"])
}

@Test func aDifferentFocusDoesNotTriggerANamedProfile() {
    let policy = focusPolicy(hosts: ["youtube.com"], profiles: [FocusProfile(id: "work", name: "Work")])
    #expect(!BlockEvaluator.isHostBlocked(
        "youtube.com", policy: policy, session: nil, now: reference,
        moment: wednesdayMidday, activeFocusIdentifiers: ["sleep"]
    ))
}

@Test func theAnyFocusProfileTriggersOnWhicheverFocusIsRunning() {
    let policy = focusPolicy(hosts: ["youtube.com"], profiles: [FocusPolicy.anyFocus])
    for active in [["work"], ["sleep"], [FocusPolicy.anyFocusIdentifier]] {
        #expect(BlockEvaluator.isHostBlocked(
            "youtube.com", policy: policy, session: nil, now: reference,
            moment: wednesdayMidday, activeFocusIdentifiers: active
        ))
    }
    #expect(!BlockEvaluator.isHostBlocked(
        "youtube.com", policy: policy, session: nil, now: reference,
        moment: wednesdayMidday, activeFocusIdentifiers: []
    ))
}

@Test func blockedAppsFollowTheSameFocusRuleAsBlockedHosts() {
    let policy = BlockPolicy(blockedApplications: [BlockedApplication(id: "com.tinyspeck.slackmacgap", name: "Slack")])
        .settingFocusProfiles([FocusProfile(id: "work", name: "Work")])

    #expect(!BlockEvaluator.isApplicationBlocked(
        bundleIdentifier: "com.tinyspeck.slackmacgap", policy: policy, session: nil,
        now: reference, moment: wednesdayMidday, activeFocusIdentifiers: []
    ))
    #expect(BlockEvaluator.isApplicationBlocked(
        bundleIdentifier: "com.tinyspeck.slackmacgap", policy: policy, session: nil,
        now: reference, moment: wednesdayMidday, activeFocusIdentifiers: ["work"]
    ))
}
