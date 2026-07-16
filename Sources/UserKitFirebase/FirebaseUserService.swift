import Foundation
import Observation
import UserKit
@preconcurrency import FirebaseAuth
import FirebaseAuthSwiftUI
import AsyncAlgorithms

// MARK: - FirebaseUserServiceConfiguration

/// App-supplied configuration for ``FirebaseUserService``. The package cannot
/// see the host app's environment, so the auth domain, bundle ID and the
/// ToS / privacy URLs are injected here rather than read from a global.
public struct FirebaseUserServiceConfiguration: Sendable {

    public var authDomain: String
    public var bundleID: String
    public var tosURL: URL?
    public var privacyPolicyURL: URL?
    public var shouldAutoUpgradeAnonymousUsers: Bool
    public var mfaEnabled: Bool

    public init(
        authDomain: String,
        bundleID: String,
        tosURL: URL? = nil,
        privacyPolicyURL: URL? = nil,
        shouldAutoUpgradeAnonymousUsers: Bool = true,
        mfaEnabled: Bool = true
    ) {
        self.authDomain = authDomain
        self.bundleID = bundleID
        self.tosURL = tosURL
        self.privacyPolicyURL = privacyPolicyURL
        self.shouldAutoUpgradeAnonymousUsers = shouldAutoUpgradeAnonymousUsers
        self.mfaEnabled = mfaEnabled
    }
}

// MARK: - FirebaseUserService

@MainActor
public struct FirebaseUserService: UserService {

    public let service: AuthService

    public init(configuration: FirebaseUserServiceConfiguration) {
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.handleCodeInApp = true
        actionCodeSettings.url = URL(string: "https://\(configuration.authDomain)")
        actionCodeSettings.setIOSBundleID(configuration.bundleID)
        actionCodeSettings.linkDomain = configuration.authDomain

        let authConfiguration = AuthConfiguration(
            shouldAutoUpgradeAnonymousUsers: configuration.shouldAutoUpgradeAnonymousUsers,
            customStringsBundle: .main,
            tosUrl: configuration.tosURL,
            privacyPolicyUrl: configuration.privacyPolicyURL,
            emailLinkSignInActionCodeSettings: actionCodeSettings,
            mfaEnabled: configuration.mfaEnabled
        )

        service = AuthService(
            configuration: authConfiguration
        )
        .withEmailSignIn()
//            .withAppleSignIn()
//            .withPhoneSignIn()
//            .withGoogleSignIn()
//            .withFacebookSignIn(FacebookProviderSwift())
//            .withTwitterSignIn()
//            .withOAuthSignIn(OAuthProviderSwift.github())
    }

    nonisolated public var isEmailVerified: any AsyncSequence<Bool, Never> & Sendable {
        AsyncStream { continuation in
            nonisolated(unsafe) let handle = Auth.auth().addStateDidChangeListener { _, user in
                continuation.yield(user?.isEmailVerified ?? false)
            }
            continuation.onTermination = { @Sendable _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }.removeDuplicates()
    }

    public func singIn() async throws {
        service.isPresented = true
    }

    public func signOut() async throws {
        try await service.signOut()
    }

    public func sendVerificationEmail() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            user.sendEmailVerification { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: Authentication

    public func authenticate() {
        service.isPresented = true
        observeAuthState(service)
    }

    public func authenticateIfNeeded() -> Bool {
        switch service.authenticationState {
        case .authenticated:
            return true
        case .authenticating:
            return false
        case .unauthenticated:
            authenticate()
            return false
        }
    }

    // MARK: With Authentication

    public func withAuthentication<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        // Already authenticated - execute immediately
        if service.authenticationState == .authenticated {
            return try await operation()
        }

        // Show auth UI if not already showing
        if service.authenticationState == .unauthenticated {
            service.isPresented = true
        }

        // Wait for auth result
        let authenticated = await awaitAuthentication(service)

        guard authenticated else {
            throw CancellationError()
        }

        return try await operation()
    }

    // MARK: Observe Authentication State

    private func awaitAuthentication(_ service: AuthService) async -> Bool {
        await withCheckedContinuation { continuation in
            observeAuthState(service, continuation: continuation)
        }
    }

    private func observeAuthState(
        _ service: AuthService,
        continuation: CheckedContinuation<Bool, Never>? = nil
    ) {
        withObservationTracking {
            _ = service.authenticationState
            _ = service.isPresented
        } onChange: {
            Task { @MainActor in
                switch service.authenticationState {
                case .authenticated:
                    service.isPresented = false
                    continuation?.resume(returning: true)
                case .unauthenticated:
                    // User cancelled (sheet dismissed while unauthenticated)
                    if !service.isPresented {
                        continuation?.resume(returning: false)
                    } else {
                        observeAuthState(service, continuation: continuation)
                    }
                case .authenticating:
                    observeAuthState(service, continuation: continuation)
                }
            }
        }
    }

}

// MARK: - User + firebaseAuthService

public extension UserKit.User {

    /// Escape hatch that hands the underlying FirebaseAuthSwiftUI `AuthService`
    /// to the app so it can present the auth UI sheet.
    var firebaseAuthService: AuthService {
        (service as! FirebaseUserService).service
    }
}
