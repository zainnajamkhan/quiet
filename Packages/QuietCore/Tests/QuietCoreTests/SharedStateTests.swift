//
//  SharedStateTests.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Testing
@testable import QuietCore

@Test func sharedStateRoundTripsThroughCoding() throws {
    let original = SharedState(preferences: ["youtube-demo.comments": false, "x.for-you": true])
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(SharedState.self, from: encoded)
    #expect(decoded == original)
}

@Test func emptySharedStateHasNoPreferences() {
    #expect(SharedState.empty.preferences.isEmpty)
}

@Test func storeRoundTripsThroughARealTemporaryFile() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("shared-state.json")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    let state = SharedState(preferences: ["youtube-demo.comments": false])
    try SharedStateStore.save(state, to: url)
    #expect(SharedStateStore.load(from: url) == state)
}

@Test func storeReturnsEmptyWhenNoFileExistsYet() {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("does-not-exist.json")
    #expect(SharedStateStore.load(from: url) == .empty)
}

@Test func storeReturnsEmptyRatherThanCrashingOnCorruptData() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("shared-state.json")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("not valid json".utf8).write(to: url)
    #expect(SharedStateStore.load(from: url) == .empty)
}

@Test func storeOverwritesRatherThanAppending() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("shared-state.json")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    try SharedStateStore.save(SharedState(preferences: ["a.b": true]), to: url)
    try SharedStateStore.save(SharedState(preferences: ["c.d": false]), to: url)
    #expect(SharedStateStore.load(from: url) == SharedState(preferences: ["c.d": false]))
}

@Test func sharedStateCarriesBlockedHosts() throws {
    let original = SharedState(preferences: ["a.b": true], blockedHosts: ["youtube.com"])
    let decoded = try JSONDecoder().decode(SharedState.self, from: JSONEncoder().encode(original))
    #expect(decoded == original)
    #expect(decoded.blockedHosts == ["youtube.com"])
}

@Test func sharedStateDecodesOlderFilesWithoutBlockedHosts() throws {
    // A file written before blockedHosts existed must still load, rather than wiping the
    // user's preferences on first launch after an update.
    let legacy = Data(#"{"preferences":{"youtube.comments":false}}"#.utf8)
    let decoded = try JSONDecoder().decode(SharedState.self, from: legacy)
    #expect(decoded.preferences == ["youtube.comments": false])
    #expect(decoded.blockedHosts.isEmpty)
}

@Test func sharedStateDecodesAnEmptyObject() throws {
    let decoded = try JSONDecoder().decode(SharedState.self, from: Data("{}".utf8))
    #expect(decoded == .empty)
}
