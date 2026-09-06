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

    /// `quiet.getSharedState` is how the extension asks whatever the native app most
    /// recently wrote (see SharedStateStore) for the current per feature preferences.
    /// Anything else is echoed back unchanged, matching the template's original demo
    /// behaviour, which is useful for confirming the message round trip during development.
    static func responsePayload(for message: Any?) -> [String: Any] {
        guard let dictionary = message as? [String: Any],
              dictionary["type"] as? String == "quiet.getSharedState"
        else {
            return [ "echo": message as Any ]
        }
        return [ "preferences": SharedStateStore.load().preferences ]
    }

}
