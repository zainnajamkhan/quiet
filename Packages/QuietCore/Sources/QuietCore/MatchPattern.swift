//
//  MatchPattern.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// A WebExtension style match pattern restricted to http and https, for example
/// `*://*.youtube.com/*`. Kept behaviourally identical to the JavaScript engine in
/// `Extension/Resources/rules-engine.js`, which is exercised by the same fixtures.
public struct MatchPattern: Equatable, Sendable {

    public enum Scheme: String, Equatable, Sendable {
        case any = "*"
        case http
        case https
    }

    public let scheme: Scheme
    public let host: String
    public let path: String

    private static let hostCharacters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
    private static let regexMetacharacters = Set("\\^$.|?*+()[]{}")

    public init?(_ pattern: String) {
        guard let schemeRange = pattern.range(of: "://") else { return nil }

        let rawScheme = String(pattern[pattern.startIndex..<schemeRange.lowerBound])
        guard let scheme = Scheme(rawValue: rawScheme.lowercased()) else { return nil }

        let remainder = pattern[schemeRange.upperBound...]
        guard let pathStart = remainder.firstIndex(of: "/") else { return nil }

        let rawHost = String(remainder[remainder.startIndex..<pathStart]).lowercased()
        guard Self.isValidHostPattern(rawHost) else { return nil }

        self.scheme = scheme
        self.host = rawHost
        self.path = String(remainder[pathStart...])
    }

    public func matches(_ urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString),
              let rawScheme = components.scheme?.lowercased(),
              let rawHost = components.host?.lowercased(),
              !rawHost.isEmpty
        else { return false }

        guard Self.schemeMatches(scheme, rawScheme) else { return false }
        guard Self.hostMatches(host, rawHost) else { return false }
        return Self.glob(path, matches: Self.pathAndQuery(of: components))
    }

    public static func pathAndQuery(of components: URLComponents) -> String {
        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        guard let query = components.percentEncodedQuery else { return path }
        return path + "?" + query
    }

    public static func glob(_ glob: String, matches value: String) -> Bool {
        var pattern = "^"
        for character in glob {
            if character == "*" {
                pattern += ".*"
            } else if regexMetacharacters.contains(character) {
                pattern += "\\" + String(character)
            } else {
                pattern.append(character)
            }
        }
        pattern += "$"

        guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.firstMatch(in: value, options: [], range: range) != nil
    }

    private static func isValidHostPattern(_ host: String) -> Bool {
        if host == "*" { return true }
        let body = host.hasPrefix("*.") ? String(host.dropFirst(2)) : host
        guard !body.isEmpty else { return false }
        return body.allSatisfy { hostCharacters.contains($0) }
    }

    private static func schemeMatches(_ pattern: Scheme, _ scheme: String) -> Bool {
        switch pattern {
        case .any: return scheme == "http" || scheme == "https"
        case .http: return scheme == "http"
        case .https: return scheme == "https"
        }
    }

    private static func hostMatches(_ pattern: String, _ host: String) -> Bool {
        if pattern == "*" { return true }
        if pattern.hasPrefix("*.") {
            let suffix = String(pattern.dropFirst(2))
            return host == suffix || host.hasSuffix("." + suffix)
        }
        return host == pattern
    }
}
