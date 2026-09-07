//
//  FocusStateTests.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Testing
@testable import QuietCore

private func temporaryURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("quiet-tests-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("focus-state.json")
}

@Test func focusStateRoundTripsThroughDisk() throws {
    let url = temporaryURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    let written = FocusState(activeIdentifiers: ["work"], updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
    try FocusStateStore.save(written, to: url)
    #expect(FocusStateStore.load(from: url) == written)
}

@Test func aMissingOrCorruptFocusFileReadsAsNoFocusRatherThanThrowing() throws {
    let url = temporaryURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    #expect(FocusStateStore.load(from: url) == .none)

    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: url)
    #expect(FocusStateStore.load(from: url) == .none)
    #expect(!FocusStateStore.load(from: url).isActive)
}

@Test func activatingReplacesRatherThanAccumulates() throws {
    let url = temporaryURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    // Switching straight from one Focus to another must not leave both active: the second
    // Focus ending would then not be enough to stop blocking.
    FocusStateStore.activate("work", to: url)
    FocusStateStore.activate("sleep", to: url)
    #expect(FocusStateStore.load(from: url).activeIdentifiers == ["sleep"])

    FocusStateStore.clear(to: url)
    #expect(FocusStateStore.load(from: url).activeIdentifiers.isEmpty)
}

@Test func clearingRecordsWhenItHappened() throws {
    let url = temporaryURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let state = FocusStateStore.clear(now: now, to: url)
    #expect(state.updatedAt == now)
    #expect(FocusStateStore.load(from: url).updatedAt == now)
}

// MARK: - Reading files written by older versions

@Test func aPolicyWrittenBeforeFocusExistedStillDecodes() throws {
    // The exact shape BlockPolicy encoded before focusProfiles was added. If this ever
    // fails to decode, an update silently wipes the user's blocklist.
    let legacy = """
    {
      "blockedApplications": [{"id": "com.tinyspeck.slackmacgap", "name": "Slack"}],
      "blockedHosts": [{"domain": "youtube.com"}],
      "schedules": [{"id": "always", "kind": "always", "enabled": true}]
    }
    """
    let policy = try JSONDecoder().decode(BlockPolicy.self, from: Data(legacy.utf8))

    #expect(policy.blockedApplications.map(\.id) == ["com.tinyspeck.slackmacgap"])
    #expect(policy.blockedHosts.map(\.domain) == ["youtube.com"])
    #expect(policy.blocksAlways)
    #expect(policy.focusProfiles.isEmpty)
}

@Test func aPolicyWithFocusProfilesRoundTrips() throws {
    let policy = BlockPolicy(blockedHosts: [HostPattern("youtube.com")!])
        .settingFocusProfiles([FocusProfile(id: "work", name: "Work"), FocusPolicy.anyFocus])
    let decoded = try JSONDecoder().decode(BlockPolicy.self, from: JSONEncoder().encode(policy))
    #expect(decoded == policy)
}

@Test func anEmptyPolicyFileDecodesToTheEmptyPolicy() throws {
    let decoded = try JSONDecoder().decode(BlockPolicy.self, from: Data("{}".utf8))
    #expect(decoded == .empty)
}
