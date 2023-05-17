// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import MozillaAppServices

let PUSH_PROD_HOST = "updates.push.services.mozilla.com"
let PUSH_STAGE_HOST = "updates-autopush.stage.mozaws.net"

public enum PushConfigurationLabel: String {
    case fennec = "fennec"
    case fennecEnterprise = "fennecenterprise"
    case firefoxBeta = "firefoxbeta"
    case firefoxNightlyEnterprise = "firefoxnightlyenterprise"
    case firefox = "firefox"

    public func toConfiguration(dbPath: String) -> PushConfiguration {
        return PushConfiguration(
            serverHost: PUSH_PROD_HOST,
            httpProtocol: PushHttpProtocol.https,
            bridgeType: BridgeType.apns,
            senderId: self.rawValue,
            databasePath: dbPath,
            verifyConnectionRateLimiter: nil
        )
    }

    public func toStagingConfiguration(dbPath: String) -> PushConfiguration {
        return PushConfiguration(
            serverHost: PUSH_STAGE_HOST,
            httpProtocol: PushHttpProtocol.https,
            bridgeType: BridgeType.apns,
            senderId: self.rawValue,
            databasePath: dbPath,
            verifyConnectionRateLimiter: nil
        )
    }

    public func toLocalConfiguration(host: String, dbPath: String) -> PushConfiguration {
        return PushConfiguration(
            serverHost: host,
            httpProtocol: PushHttpProtocol.http,
            bridgeType: BridgeType.apns,
            senderId: self.rawValue,
            databasePath: dbPath,
            verifyConnectionRateLimiter: nil
        )
    }
}
