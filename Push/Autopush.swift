// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Shared
import MozillaAppServices

open class Autopush {
    private var pushClient: PushManagerProtocol?
    private let dbPath: String

    public init(dbPath: String) {
        self.dbPath = dbPath
        self.pushClient = nil
    }

    private func withClient(_ fn: @escaping (PushManagerProtocol) -> Void) {
        guard let pushClient = pushClient else {
            return
        }
        DispatchQueue.global(qos: .default).async {
            fn(pushClient)
        }
    }

    public func reopenIfClosed(completion: @escaping () -> Void = {}) {
        guard pushClient == nil else {
            return
        }
        DispatchQueue.global(qos: .default).async {
            do {
                self.pushClient = try PushManager(config: PushConfigurationLabel.fennec.toConfiguration(dbPath: self.dbPath))
                completion()
            } catch {
                // TODO: Error handling, what should happen if we can't even open the client?
            }
        }
    }

    public func didRegister(withDeviceToken deviceToken: Data, completion: @escaping () -> Void, errCompletion: @escaping (Error) -> Void) {
        withClient { pushClient in
            do {
                try pushClient.update(registrationToken: deviceToken.hexEncodedString)
                completion()
            } catch let e {
                errCompletion(e)
            }
        }
    }

    public func subscribe(scope: String, completion: @escaping (SubscriptionResponse) -> Void, errCompletion: @escaping (Error) -> Void) {
        withClient { pushClient in
            do {
                let res = try pushClient.subscribe(scope: scope, appServerSey: nil)
                completion(res)
            } catch let e {
                errCompletion(e)
            }
        }
    }

    public func unsubscribe(scope: String, completion: @escaping () -> Void, errCompletion: @escaping (Error) -> Void) {
        withClient { pushClient in
            do {
                try pushClient.unsubscribe(scope: scope)
                completion()
            } catch let e {
                errCompletion(e)
            }
        }
    }

    public func decrypt(payload: [String: String], completion: @escaping (DecryptResponse) -> Void, errCompletion: @escaping (Error) -> Void) {
        withClient { pushClient in
            do {
                let res = try pushClient.decrypt(payload: payload)
                completion(res)
            } catch let e {
                errCompletion(e)
            }
        }
    }
}
