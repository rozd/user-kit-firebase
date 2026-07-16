import Foundation
import UserKit
@preconcurrency import FirebaseAuth

// MARK: - FirebaseUserInfo

public struct FirebaseUserInfo: UserKit.UserInfo, @unchecked Sendable {

    nonisolated(unsafe) let user: FirebaseAuth.User
    nonisolated(unsafe) let claims: [String: Any]
    let userId: UserId

    init(
        user: FirebaseAuth.User,
        claims: [String: Any]
    ) {
        self.user = user
        self.claims = claims
        self.userId = UserId(user.uid)
    }

    public var id: UserId { userId }

    /// Overrides the core default (`nil`) with the Firebase JWT `role` custom
    /// claim, which is what `UserInfo.isAdmin` reads.
    public var role: String? {
        claims["role"] as? String
    }

    public var session: any UserSession {
        FirebaseUserSession(user: user)
    }

    public var profile: any UserProfile {
        FirebaseUserProfile(user: user)
    }
}

// MARK: - FirebaseUserProfile

public struct FirebaseUserProfile: UserProfile, @unchecked Sendable {
    nonisolated(unsafe) let user: FirebaseAuth.User

    public var displayName: String? {
        user.displayName
    }
}

// MARK: - FirebaseUserSession

public struct FirebaseUserSession: UserSession, @unchecked Sendable {
    nonisolated(unsafe) let user: FirebaseAuth.User

    public var isAuthenticated: Bool {
        user.refreshToken != nil
    }

    public var refreshToken: String? {
        user.refreshToken
    }

    public var accessToken: String? {
        get async {
            await withCheckedContinuation { continuation in
                user.getIDToken(completion: { token, error in
                    continuation.resume(returning: token)
                })
            }
        }
    }
}

// MARK: - FirebaseAuth.User Helpers

extension FirebaseAuth.User {

    func toUserInfo() async -> FirebaseUserInfo {
        let claims = await withCheckedContinuation { (continuation: CheckedContinuation<SendableClaims, Never>) in
            self.getIDTokenResult { tokenResult, _ in
                continuation.resume(returning: SendableClaims(tokenResult?.claims ?? [:]))
            }
        }
        return FirebaseUserInfo(user: self, claims: claims.value)
    }

    @discardableResult
    func refreshToken() async -> String? {
        await withCheckedContinuation { continuation in
            self.getIDTokenForcingRefresh(true, completion: { token, error in
                continuation.resume(returning: token)
            })
        }
    }
}

// MARK: - SendableClaims

private struct SendableClaims: @unchecked Sendable {
    let value: [String: Any]
    init(_ value: [String: Any]) {
        self.value = value
    }
}
