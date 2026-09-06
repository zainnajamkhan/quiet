//
//  PurchaseObserving.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// The seam between this package's pure decision logic and StoreKit 2, which is async,
/// talks to a remote server and cannot be unit tested the way `LicenseState` is. An app
/// target implements this against `Transaction.currentEntitlements` for its own product
/// identifier; nothing in `IndieKit` depends on StoreKit itself.
public protocol PurchaseObserving: Sendable {
    var isPurchased: Bool { get async }
    func restorePurchases() async throws
}
