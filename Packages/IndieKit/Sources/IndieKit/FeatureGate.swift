//
//  FeatureGate.swift
//  Quiet
//
//  Created by Zain Najam on 06/09/2026.
//  Copyright © 2026 Zain Najam. All rights reserved.
//

import Foundation

/// For the free-tier-plus-unlock model (Quiet, Redact): some features are free forever,
/// the rest need a purchase. There is deliberately no trial concept in this function, since
/// a permanently free tier and a time limited trial are different products; an app that
/// wants both composes `LicenseState.hasFullAccess` with this.
public enum FeatureGate {
    public static func isUnlocked(isFreeTier: Bool, license: LicenseState, asOf now: Date = Date()) -> Bool {
        isFreeTier || license.hasFullAccess(asOf: now)
    }
}
