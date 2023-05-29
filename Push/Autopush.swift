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

    private func withClient<T>(_ fn: @escaping (PushManagerProtocol) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            guard let pushClient = pushClient else {
                continuation.resume(throwing: PushApiError.InternalError(message: ("No push client initialized")))
                return
            }
            DispatchQueue.global().async {
                do {
                    let ret = try fn(pushClient)
                    continuation.resume(returning: ret)
                } catch let e {
                    continuation.resume(throwing: e)
                }
            }
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

    public func didRegister(withDeviceToken deviceToken: Data) async throws {
        try await withClient { pushClient in
            try pushClient.update(registrationToken: deviceToken.hexEncodedString)
        }
    }

    public func subscribe(scope: String) async throws -> SubscriptionResponse {
        try await withClient { pushClient in
            return try pushClient.subscribe(scope: scope, appServerSey: nil)
        }
    }

    public func unsubscribe(scope: String) async throws -> Bool {
        return try await withClient { pushClient in
            return try pushClient.unsubscribe(scope: scope)
        }
    }

    public func decrypt(payload: [String: String]) async throws -> DecryptResponse {
        return try await withClient { pushClient in
            return try pushClient.decrypt(payload: payload)
        }
    }
}
