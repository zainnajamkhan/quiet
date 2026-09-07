//
//  HostPattern.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// A domain the user wants blocked, normalised from whatever they typed. People paste
/// "https://www.YouTube.com/feed/", type " youtube.com ", or write "YouTube.com." and all
/// of those mean the same site, so normalisation happens once here rather than at every
/// comparison site.
public struct HostPattern: Codable, Equatable, Hashable, Sendable {

    public let domain: String

    private static let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789.-")

    public init?(_ raw: String) {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return nil }

        if let range = value.range(of: "://") {
            value = String(value[range.upperBound...])
        }
        if let index = value.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) {
            value = String(value[value.startIndex..<index])
        }
        if let colon = value.firstIndex(of: ":") {
            value = String(value[value.startIndex..<colon])
        }
        while value.hasSuffix(".") {
            value.removeLast()
        }
        if value.hasPrefix("www.") {
            value = String(value.dropFirst(4))
        }

        guard !value.isEmpty,
              value.allSatisfy({ Self.allowed.contains($0) }),
              !value.hasPrefix("."),
              !value.hasPrefix("-"),
              !value.contains("..")
        else { return nil }

        // A single label is not a blockable site. This rejects leftovers from malformed
        // input such as "www." (which normalises to a bare "www") while still allowing the
        // one single label host that is genuinely useful to block.
        guard value.contains(".") || value == "localhost" else { return nil }

        self.domain = value
    }

    /// Matches the domain itself and any subdomain of it, so blocking "reddit.com" also
    /// blocks "old.reddit.com". Deliberately does not match a domain that merely ends with
    /// the same letters, which is the classic bug here: "notreddit.com" is a different site.
    public func matches(host rawHost: String) -> Bool {
        let host = rawHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !host.isEmpty else { return false }
        let stripped = host.hasSuffix(".") ? String(host.dropLast()) : host
        return stripped == domain || stripped.hasSuffix("." + domain)
    }

    public func matches(url urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString), let host = components.host else { return false }
        return matches(host: host)
    }
}
