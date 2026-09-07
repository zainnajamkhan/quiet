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
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                Text("Quiet Pro")
                    .font(.largeTitle.weight(.semibold))
                Text("One payment. No subscription.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                benefit("eye.slash", "Every supported site", "Free covers \(FreeTierPolicy.freeSiteLimit) at a time.")
                benefit("hand.raised", "Block websites outright", "Not just tidied up. Shut.")
                benefit("macwindow", "Block apps on your Mac", "Slack, games, other browsers.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                Button {
                    Task { await purchases.purchase() }
                } label: {
                    Group {
                        if purchases.isPurchasing {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Unlock for \(priceText)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(purchases.isPurchasing)

                Button("Restore Purchase") {
                    Task { await purchases.restore() }
                }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
                .disabled(purchases.isPurchasing)
            }

            if let error = purchases.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
