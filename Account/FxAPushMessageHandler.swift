// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Shared
import SyncTelemetry
import Account
import MozillaAppServices
import Common

let PendingAccountDisconnectedKey = "PendingAccountDisconnect"

/// This class provides handles push messages from FxA.
/// For reference, the [message schema][0] and [Android implementation][1] are both useful resources.
/// [0]: https://github.com/mozilla/fxa-auth-server/blob/master/docs/pushpayloads.schema.json#L26
/// [1]: https://dxr.mozilla.org/mozilla-central/source/mobile/android/services/src/main/java/org/mozilla/gecko/fxa/FxAccountPushHandler.java
/// The main entry points are `handle` methods, to accept the raw APNS `userInfo` and then to process the resulting JSON.
class FxAPushMessageHandler {
    let profile: Profile
    private let logger: Logger

    init(with profile: Profile, logger: Logger = DefaultLogger.shared) {
        self.profile = profile
        self.logger = logger
    }
}

extension FxAPushMessageHandler {
    /// Accepts the raw Push message from Autopush.
    /// This method then decrypts it according to the content-encoding (aes128gcm or aesgcm)
    /// and then effects changes on the logged in account.
    @discardableResult
    func handle(userInfo: [AnyHashable: Any]) -> PushMessageResults {
        var payload: [String:String] = [:]
        for (key, value) in userInfo {
            if let key = key as? String, let value = value as? String {
                payload[key] = value
            }
        }

        let deferred = PushMessageResults()
        

        let pushManager = self.profile.pushManager
        let payloadV = payload
        let handle = Task(priority: nil) {
            let decryptResult = try await pushManager.decrypt(payload: payloadV)
            guard let decryptedString = String(bytes: decryptResult.result.map {byte in UInt8(byte) }, encoding: .utf8) else {
                // The app will detect this missing, and re-register. see AppDelegate+PushNotifications.swift.
                // TODO: Do something here
                deferred.fill(Maybe(failure: PushMessageError.messageIncomplete("oops")))
                return
            }
            // Reconfig has to happen on the main thread, since it calls `startup`
            // and `startup` asserts that we are on the main thread. Otherwise the notification
            // service will crash.
            DispatchQueue.main.async {
                RustFirefoxAccounts.reconfig(prefs: self.profile.prefs).uponQueue(.main) { accountManager in
                    accountManager.deviceConstellation()?.handlePushMessage(pushPayload: decryptedString) {
                        result in
                        guard case .success(let event) = result else {
                            let err: PushMessageError
                            if case .failure(let error) = result {
                                self.logger.log("Failed to get any events from FxA",
                                                level: .warning,
                                                category: .sync,
                                                description: error.localizedDescription)
                                err = PushMessageError.messageIncomplete(error.localizedDescription)
                            } else {
                                self.logger.log("Got zero events from FxA",
                                                level: .warning,
                                                category: .sync,
                                                description: "No events retrieved from fxa")
                                err = PushMessageError.messageIncomplete("empty message")
                            }
                            deferred.fill(Maybe(failure: err))
                            return
                        }

                        switch event {
                        case .commandReceived(let deviceCommand):
                            switch deviceCommand {
                            case .tabReceived(_, let tabData):
                                let title = tabData.entries.last?.title ?? ""
                                let url = tabData.entries.last?.url ?? ""
                                deferred.fill(Maybe(success: PushMessage.commandReceived(tab: ["title": title, "url": url])))
                            }
                        case .deviceConnected(let deviceName):
                            deferred.fill(Maybe(success: PushMessage.deviceConnected(deviceName)))
                        case let .deviceDisconnected(deviceId, isLocalDevice):
                            if isLocalDevice {
                                // We can't disconnect the device from the account until we have access to the application, so we'll handle this properly in the AppDelegate (as this code in an extension),
                                // by calling the FxALoginHelper.applicationDidDisonnect(application).
                                self.profile.prefs.setBool(true, forKey: PendingAccountDisconnectedKey)
                                deferred.fill(Maybe(success: PushMessage.thisDeviceDisconnected))
                            }

                            guard let profile = self.profile as? BrowserProfile else {
                                // We can't look up a name in testing, so this is the same as not knowing about it.
                                deferred.fill(Maybe(success: PushMessage.deviceDisconnected(nil)))
                                break
                            }

                            profile.getClient(fxaDeviceId: deviceId).uponQueue(.main) { result in
                                guard let device = result.successValue else {
                                    deferred.fill(Maybe(failure: result.failureValue ?? "Unknown Error"))
                                    return
                                }
                                deferred.fill(Maybe(success: PushMessage.deviceDisconnected(device?.name)))
                                if let id = device?.guid {
                                    profile.remoteClientsAndTabs.deleteClient(guid: id).uponQueue(.main) { _ in }
                                }
                            }
                        default:
                            // There are other events, but we ignore them at this level.
                            break
                        }
                    }
                }
            }
        }
        return deferred
    }
}

enum PushMessageType: String {
    case commandReceived = "fxaccounts:command_received"
    case deviceConnected = "fxaccounts:device_connected"
    case deviceDisconnected = "fxaccounts:device_disconnected"
    case profileUpdated = "fxaccounts:profile_updated"
    case passwordChanged = "fxaccounts:password_changed"
    case passwordReset = "fxaccounts:password_reset"
}

enum PushMessage: Equatable {
    case commandReceived(tab: [String: String])
    case deviceConnected(String)
    case deviceDisconnected(String?)
    case profileUpdated
    case passwordChanged
    case passwordReset

    // This is returned when we detect that it is us that has been disconnected.
    case thisDeviceDisconnected

    var messageType: PushMessageType {
        switch self {
        case .commandReceived:
            return .commandReceived
        case .deviceConnected:
            return .deviceConnected
        case .deviceDisconnected:
            return .deviceDisconnected
        case .thisDeviceDisconnected:
            return .deviceDisconnected
        case .profileUpdated:
            return .profileUpdated
        case .passwordChanged:
            return .passwordChanged
        case .passwordReset:
            return .passwordReset
        }
    }

    public static func == (lhs: PushMessage, rhs: PushMessage) -> Bool {
        guard lhs.messageType == rhs.messageType else {
            return false
        }

        switch (lhs, rhs) {
        case (.commandReceived(let lIndex), .commandReceived(let rIndex)):
            return lIndex == rIndex
        case (.deviceConnected(let lName), .deviceConnected(let rName)):
            return lName == rName
        default:
            return true
        }
    }
}

typealias PushMessageResults = Deferred<Maybe<PushMessage>>

enum PushMessageError: MaybeErrorType {
    case notDecrypted
    case messageIncomplete(String)
    case unimplemented(PushMessageType)
    case timeout
    case accountError
    case noProfile
    case subscriptionOutOfDate

    public var description: String {
        switch self {
        case .notDecrypted: return "notDecrypted"
        case .messageIncomplete(let message): return "messageIncomplete=\(message)"
        case .unimplemented(let what): return "unimplemented=\(what)"
        case .timeout: return "timeout"
        case .accountError: return "accountError"
        case .noProfile: return "noProfile"
        case .subscriptionOutOfDate: return "subscriptionOutOfDate"
        }
    }
}
