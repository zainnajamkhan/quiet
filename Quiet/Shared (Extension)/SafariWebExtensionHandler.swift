//
//  SafariWebExtensionHandler.swift
//  Shared (Extension)
//
//  Created by Zain Najam Khan 1 on 06/09/2026.
//

import SafariServices
import os.log
import QuietCore

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        os_log(.default, "Received message from browser.runtime.sendNativeMessage: %@", String(describing: message))

        let responsePayload = Self.responsePayload(for: message)

        let response = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [ SFExtensionMessageKey: responsePayload ]
        } else {
            response.userInfo = [ "message": responsePayload ]
        }

        context.completeRequest(returningItems: [ response ], completionHandler: nil)
    }

    /// The native side of the extension's two questions. Anything else is echoed back
    /// unchanged, matching the template's original demo behaviour, which is useful for
    /// confirming the message round trip during development.
    ///
    /// - `quiet.getSharedState` asks what the app most recently wrote (see SharedStateStore)
    ///   for per feature preferences and the currently blocked hosts.
    /// - `quiet.getRemoteRuleset` asks for a rule update the app has downloaded and
    ///   validated. The extension cannot fetch this itself: it has no network permission and
    ///   no way to reach CloudKit, and giving it one would mean two copies of the code that
    ///   decides which rules are safe to run.
    static func responsePayload(for message: Any?) -> [String: Any] {
        guard let dictionary = message as? [String: Any], let type = dictionary["type"] as? String else {
            return [ "echo": message as Any ]
        }

        switch type {
        case "quiet.getSharedState":
            let state = SharedStateStore.load()
            return [
                "preferences": state.preferences,
                "blockedHosts": state.blockedHosts,
            ]

        case "quiet.getRemoteRuleset":
            return [ "ruleset": remoteRulesetPayload() as Any ]

        default:
            return [ "echo": message as Any ]
        }
    }

    /// The accepted remote ruleset as a plain dictionary, or nil when none has ever been
    /// accepted. Re-encoding through JSON rather than hand building the dictionary keeps
    /// this in step with the model automatically: a field added to Ruleset reaches the
    /// extension without anyone remembering to mirror it here.
    private static func remoteRulesetPayload() -> [String: Any]? {
        guard let ruleset = RulesetUpdateStore.load().ruleset,
              let data = try? JSONEncoder().encode(ruleset),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }

}
