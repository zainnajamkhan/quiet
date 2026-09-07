//
//  BlockPolicyStore.swift
//  Quiet
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// Persists the block policy alongside shared state, in the same App Group container so
/// the extension can read the resolved host list without a second sharing mechanism.
public enum BlockPolicyStore {

    public static func fileURL() -> URL {
        SharedStateStore.fileURL().deletingLastPathComponent().appendingPathComponent("block-policy.json")
    }

    public static func load(from url: URL = fileURL()) -> BlockPolicy {
        guard let data = try? Data(contentsOf: url) else { return .empty }
        return (try? JSONDecoder().decode(BlockPolicy.self, from: data)) ?? .empty
    }

    public static func save(_ policy: BlockPolicy, to url: URL = fileURL()) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(policy).write(to: url, options: .atomic)
    }
}
