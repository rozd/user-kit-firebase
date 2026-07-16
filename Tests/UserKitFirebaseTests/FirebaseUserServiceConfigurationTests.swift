import Testing
import Foundation
@testable import UserKitFirebase

@Suite("FirebaseUserServiceConfiguration")
struct FirebaseUserServiceConfigurationTests {

    @Test("defaults match the previous hard-coded service behaviour")
    func defaults() {
        let config = FirebaseUserServiceConfiguration(
            authDomain: "example.firebaseapp.com",
            bundleID: "com.example.app"
        )
        #expect(config.authDomain == "example.firebaseapp.com")
        #expect(config.bundleID == "com.example.app")
        #expect(config.tosURL == nil)
        #expect(config.privacyPolicyURL == nil)
        #expect(config.shouldAutoUpgradeAnonymousUsers == true)
        #expect(config.mfaEnabled == true)
    }

    @Test("URLs and flags round-trip through the initializer")
    func explicitValues() {
        let config = FirebaseUserServiceConfiguration(
            authDomain: "d",
            bundleID: "b",
            tosURL: URL(string: "https://example.com/tos"),
            privacyPolicyURL: URL(string: "https://example.com/privacy"),
            shouldAutoUpgradeAnonymousUsers: false,
            mfaEnabled: false
        )
        #expect(config.tosURL?.absoluteString == "https://example.com/tos")
        #expect(config.privacyPolicyURL?.absoluteString == "https://example.com/privacy")
        #expect(config.shouldAutoUpgradeAnonymousUsers == false)
        #expect(config.mfaEnabled == false)
    }
}
