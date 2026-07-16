import UserKit
@preconcurrency import FirebaseAuth

public struct FirebaseUserSynchronizer: UserSynchronizer {

    public init() {}

    public func install() -> any AsyncSequence<(any UserKit.UserInfo)?, Never> & Sendable {
        AsyncStream { continuation in
            nonisolated(unsafe) let handle = Auth.auth().addStateDidChangeListener { _, user in
                if let user {
                    Task {
                        let userInfo = await user.toUserInfo()
                        continuation.yield(userInfo)
                    }
                } else {
                    continuation.yield(nil)
                }
            }
            continuation.onTermination = { @Sendable _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }

    public func dispose() {
        // No-op
    }
}
