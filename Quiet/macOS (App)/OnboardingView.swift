//
//  OnboardingView.swift
//  macOS (App)
//
//  Created by Zain Najam on 07/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import SwiftUI
import QuietCore

/// One job: get the Safari extension switched on.
///
/// This is the single biggest drop off point for a Safari extension app. Safari ships new
/// extensions disabled and never prompts, so someone who does not know to go and enable it
/// concludes the app is broken. Everything else the app can explain later, in place.
struct OnboardingView: View {

    @ObservedObject var extensionStatus: ExtensionStatusModel
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text("Quiet")
                    .font(.largeTitle.weight(.semibold))
                Text("Keep the sites you need.\nLose the parts that eat you.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 44)
            .padding(.bottom, 30)

            VStack(spacing: 14) {
                Text("Safari ships new extensions switched off.")
                    .font(.headline)

                statusCard

                Button("Open Safari Settings…") { extensionStatus.openSafariSettings() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.horizontal, 40)

            Spacer(minLength: 20)

            HStack {
                Button("Check Again") { extensionStatus.refresh() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(extensionStatus.isEnabled ? "Start" : "Skip for now", action: onFinish)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(minWidth: 460, minHeight: 460)
        .onAppear { extensionStatus.refresh() }
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            Image(systemName: status.symbol)
                .foregroundStyle(status.tint)
            Text(status.text)
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(status.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var status: (symbol: String, text: String, tint: Color) {
        switch extensionStatus.state {
        case .enabled: ("checkmark.circle.fill", "Quiet is on in Safari", .green)
        case .disabled: ("xmark.circle.fill", "Quiet is off in Safari", .orange)
        case .unknown: ("clock", "Checking…", .secondary)
        case .failed(let message): ("exclamationmark.triangle.fill", message, .red)
        }
    }
}
