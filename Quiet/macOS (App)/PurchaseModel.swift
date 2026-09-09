//
//  PurchaseModel.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation
import Combine
import StoreKit
import IndieKit
import os.log

/// The StoreKit 2 side of licensing. IndieKit deliberately owns no StoreKit code: this is
/// the concrete implementation of its PurchaseObserving seam, so the pure entitlement
/// rules stay unit testable while the part that talks to Apple's servers lives here.
@MainActor
final class PurchaseModel: ObservableObject {

    static let productIdentifier = "com.app.Quiet.pro"

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    @Published private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        // Transactions can arrive at any time: a purchase finished on another device, a
        // parent approving Ask to Buy, or a refund. Without this listener entitlement
        // would only ever be correct at launch.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await self.apply(transaction)
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func start() async {
        await loadProduct()
        await refreshEntitlements()
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productIdentifier])
            product = products.first
            if product == nil {
                os_log(.default, "Quiet: no StoreKit product found for %{public}@", Self.productIdentifier)
            }
        } catch {
            os_log(.default, "Quiet: failed to load products: %{public}@", String(describing: error))
        }
    }

    /// Records entitlement from a single transaction. Only ever grants: a lone transaction
    /// is evidence that something was bought, never evidence that nothing else was.
    private func apply(_ transaction: Transaction) {
        guard transaction.productID == Self.productIdentifier else { return }
        if transaction.revocationDate == nil {
            isPro = true
        }
    }

    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productIdentifier, transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPro = entitled
    }

    func purchase() async {
        guard let product else {
            lastError = "The Quiet Pro product is not available right now."
            return
        }
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    // Trust the transaction that was just verified rather than asking
                    // Transaction.currentEntitlements what it thinks. That query can still
                    // be answering from a stale cache immediately after a purchase, which
                    // leaves the app showing a paywall to somebody who has just paid, with
                    // no way forward but relaunching. The listener in init() and the check
                    // at launch remain the authority for refunds and other devices.
                    apply(transaction)
                    await transaction.finish()
                } else {
                    lastError = "That purchase could not be verified."
                }
            case .userCancelled:
                break
            case .pending:
                lastError = "Your purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro {
                lastError = "No previous purchase was found on this Apple Account."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}

extension PurchaseModel: @unchecked Sendable {}
