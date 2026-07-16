import UserKit
@preconcurrency import FirebaseAuth

public struct FirebaseUserStorage: UserStorage {

    public init() {}

    public func fetch() async -> (any UserKit.UserInfo)? {
        guard let user = Auth.auth().currentUser else { return nil }
        await user.refreshToken()
        return await user.toUserInfo()
    }

    public func store(userInfo info: any UserKit.UserInfo) async {
        // No-op
    }

    public func clear() async {
        // No-op
    }
}
