//
//  BlockPolicyDecodingTests.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Testing
@testable import QuietCore

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
}

@Test func aPolicyRoundTripsThroughJSON() throws {
    let policy = BlockPolicy(blockedHosts: [HostPattern("youtube.com")!]).settingBlocksAlways(true)
    let decoded = try JSONDecoder().decode(BlockPolicy.self, from: JSONEncoder().encode(policy))
    #expect(decoded == policy)
}

@Test func aPolicyWrittenWhileFocusModeExistedStillDecodes() throws {
    // Focus mode was built and then cut. Files from that build carry a focusProfiles key
    // and focus schedules; both must be ignored rather than causing a decode failure that
    // would wipe the user's blocklist.
    let withFocus = """
    {
      "blockedHosts": [{"domain": "youtube.com"}],
      "focusProfiles": [{"id": "work", "name": "Work"}],
      "schedules": [{"id": "focus-work", "kind": "focus", "enabled": true, "focusIdentifiers": ["work"]}]
    }
    """
    let policy = try JSONDecoder().decode(BlockPolicy.self, from: Data(withFocus.utf8))
    #expect(policy.blockedHosts.map(\.domain) == ["youtube.com"])
}

@Test func anEmptyPolicyFileDecodesToTheEmptyPolicy() throws {
    let decoded = try JSONDecoder().decode(BlockPolicy.self, from: Data("{}".utf8))
    #expect(decoded == .empty)
}
