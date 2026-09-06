//
//  Ruleset.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

public struct Ruleset: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let rulesetVersion: Int
    public let updatedAt: String?
    public let sites: [Site]

    public init(schemaVersion: Int, rulesetVersion: Int, updatedAt: String? = nil, sites: [Site]) {
        self.schemaVersion = schemaVersion
        self.rulesetVersion = rulesetVersion
        self.updatedAt = updatedAt
        self.sites = sites
    }
}

public struct Site: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let matches: [String]
    public let features: [Feature]

    public init(id: String, name: String, matches: [String], features: [Feature]) {
        self.id = id
        self.name = name
        self.matches = matches
        self.features = features
    }
}

public struct Feature: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let summary: String?
    public let defaultEnabled: Bool
    public let appliesTo: [String]?
    public let hide: [String]
    public let verify: [String]?

    public init(
        id: String,
        name: String,
        summary: String? = nil,
        defaultEnabled: Bool,
        appliesTo: [String]? = nil,
        hide: [String],
        verify: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.defaultEnabled = defaultEnabled
        self.appliesTo = appliesTo
        self.hide = hide
        self.verify = verify
    }
}

public extension Ruleset {
    /// The schema shape this build understands. A ruleset declaring anything else is refused.
    static let supportedSchemaVersion = 1

    static func decode(from data: Data) throws -> Ruleset {
        try JSONDecoder().decode(Ruleset.self, from: data)
    }

    func site(withID id: String) -> Site? {
        sites.first { $0.id == id }
    }

    var allFeatures: [Feature] {
        sites.flatMap(\.features)
    }
}
