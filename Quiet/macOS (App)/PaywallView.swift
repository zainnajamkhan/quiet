//
//  PaywallView.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import SwiftUI
import StoreKit
import QuietCore

struct PaywallView: View {
    @ObservedObject var purchases: PurchaseModel

    private var priceText: String {
        purchases.product?.displayPrice ?? "$24.99"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quiet Pro")
                .font(.title2.weight(.semibold))

            Text("One payment. No subscription. Everything below, on every Apple device you own.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Label("Hide distractions on every supported site, not just \(FreeTierPolicy.freeSiteLimit)", systemImage: "eye.slash")
                Label("Block websites outright", systemImage: "hand.raised")
                Label("Block distracting apps on your Mac", systemImage: "macwindow")
            }
            .font(.callout)

            if let error = purchases.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button {
                    Task { await purchases.purchase() }
                } label: {
                    if purchases.isPurchasing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Unlock for \(priceText)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(purchases.isPurchasing)

                Button("Restore Purchase") {
                    Task { await purchases.restore() }
                }
                .disabled(purchases.isPurchasing)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}
