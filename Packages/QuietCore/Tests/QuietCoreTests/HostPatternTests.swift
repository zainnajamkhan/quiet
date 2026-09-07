//
//  HostPatternTests.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Testing
@testable import QuietCore

@Test(arguments: [
    ("youtube.com", "youtube.com"),
    ("  youtube.com  ", "youtube.com"),
    ("YouTube.com", "youtube.com"),
    ("www.youtube.com", "youtube.com"),
    ("https://youtube.com", "youtube.com"),
    ("http://www.youtube.com", "youtube.com"),
    ("https://www.youtube.com/feed/subscriptions", "youtube.com"),
    ("youtube.com/feed", "youtube.com"),
    ("youtube.com:8080", "youtube.com"),
    ("youtube.com.", "youtube.com"),
    ("https://www.YouTube.com./watch?v=1", "youtube.com"),
    ("old.reddit.com", "old.reddit.com"),
    ("localhost", "localhost"),
])
func normalisesWhateverTheUserTyped(input: String, expected: String) {
    #expect(HostPattern(input)?.domain == expected, "input: \(input)")
}

@Test(arguments: ["", "   ", "https://", "://", "/", "?", "www.", ".", "..", "a b.com", "-bad.com", ".bad.com", "bad..com"])
func rejectsUnusableInput(input: String) {
    #expect(HostPattern(input) == nil, "should reject: \(input)")
}

@Test func matchesTheDomainItselfAndItsSubdomains() throws {
    let pattern = try #require(HostPattern("reddit.com"))
    #expect(pattern.matches(host: "reddit.com"))
    #expect(pattern.matches(host: "old.reddit.com"))
    #expect(pattern.matches(host: "www.reddit.com"))
    #expect(pattern.matches(host: "a.b.reddit.com"))
    #expect(pattern.matches(host: "REDDIT.COM"))
    #expect(pattern.matches(host: "reddit.com."))
}

@Test func doesNotMatchLookalikeDomains() throws {
    let pattern = try #require(HostPattern("reddit.com"))
    #expect(!pattern.matches(host: "notreddit.com"))
    #expect(!pattern.matches(host: "reddit.com.evil.test"))
    #expect(!pattern.matches(host: "myreddit.como"))
    #expect(!pattern.matches(host: ""))
}

@Test func aSubdomainPatternDoesNotBlockTheParent() throws {
    let pattern = try #require(HostPattern("old.reddit.com"))
    #expect(pattern.matches(host: "old.reddit.com"))
    #expect(!pattern.matches(host: "reddit.com"))
    #expect(!pattern.matches(host: "new.reddit.com"))
}

@Test func matchesFullURLs() throws {
    let pattern = try #require(HostPattern("youtube.com"))
    #expect(pattern.matches(url: "https://www.youtube.com/watch?v=abc"))
    #expect(pattern.matches(url: "http://m.youtube.com/"))
    #expect(!pattern.matches(url: "https://vimeo.com/"))
    #expect(!pattern.matches(url: "not a url"))
}

@Test func normalisationMakesEqualityWork() {
    #expect(HostPattern("https://www.YouTube.com/feed") == HostPattern("youtube.com"))
    #expect(Set([HostPattern("www.youtube.com"), HostPattern("youtube.com")]).count == 1)
}
