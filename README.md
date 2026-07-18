# UserKitFirebase

A [Firebase Authentication](https://firebase.google.com/docs/auth) provider adapter for [UserKit](https://github.com/rozd/user-kit) — the provider-neutral "current authenticated user" layer for SwiftUI apps.

UserKit ships only protocols and a `@MainActor @Observable` `User` orchestrator, with no concrete auth provider. This package fills in that seam with Firebase: it conforms concrete types to UserKit's `UserService` / `UserStorage` / `UserSynchronizer` protocols (backed by `FirebaseAuth` and `FirebaseAuthSwiftUI`) so an app can drive sign-in, session, and role state through the neutral UserKit API.

## Requirements

- iOS 18+
- Swift 6.2 / Xcode 16+
- A configured Firebase project (`GoogleService-Info.plist`, `FirebaseApp.configure()` at launch)

## Installation

Add the package with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/rozd/user-kit-firebase", branch: "main"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "UserKitFirebase", package: "user-kit-firebase"),
        ]
    ),
]
```

`UserKitFirebase` transitively brings in `UserKit`, `firebase-ios-sdk`, and `FirebaseUI-iOS`. Pin the Firebase SDKs to exactly the versions your app already resolves so adding the adapter doesn't perturb your dependency graph.

## Usage

Assemble the pieces this package provides and hand them to UserKit's `User`. The app owns the `User` instance (typically a single `User.current`) and injects environment-specific values through `FirebaseUserServiceConfiguration` — the package can't read your app's config on its own.

```swift
import UserKit
import UserKitFirebase

let config = FirebaseUserServiceConfiguration(
    authDomain: AppEnvironment.firebaseAuthDomain,   // e.g. "myapp.firebaseapp.com"
    bundleID: Bundle.main.bundleIdentifier!,
    tosURL: URL(string: "https://myapp.example/tos"),
    privacyPolicyURL: URL(string: "https://myapp.example/privacy")
)

let user = User(
    service: FirebaseUserService(configuration: config),
    storage: FirebaseUserStorage(),
    synchronizer: FirebaseUserSynchronizer()
)
```

From there, drive auth through the neutral UserKit API (`user.authenticate()`, `user.signIn()`, `user.isAuthenticated`, `user.isAdmin`, …). Calling `authenticate()` flips the underlying `AuthService.isPresented`; to actually present the FirebaseAuthSwiftUI sign-in flow, reach that service through the `firebaseAuthService` escape hatch and wire it into your view per the [FirebaseAuthSwiftUI](https://github.com/firebase/FirebaseUI-iOS) docs:

```swift
let authService = user.firebaseAuthService   // the FirebaseAuthSwiftUI AuthService
```

### What the adapter surfaces

- **`FirebaseUserService`** — sign in / out, email verification, and the auth-presentation state.
- **`FirebaseUserStorage`** — reads the current Firebase user; `store`/`clear` are intentional no-ops because Firebase owns session persistence.
- **`FirebaseUserSynchronizer`** — bridges Firebase's auth-state listener into an `AsyncSequence` of `UserInfo?`.
- **`FirebaseUserInfo`** — exposes the JWT `role` custom claim, which is what UserKit's `isAdmin` (`role == "admin"`) reads.

## Building & testing

This package is iOS-only, so the SwiftPM CLI (`swift build` / `swift test`) does **not** work — build against an iOS destination instead:

```sh
xcodebuild build -scheme UserKitFirebase -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -scheme UserKitFirebase -destination 'platform=iOS Simulator,name=iPhone 17'
```

Tests use [swift-testing](https://github.com/swiftlang/swift-testing). Formatting is configured in `.swift-format` (`swift format --in-place --recursive Sources Tests`).

## License

See [LICENSE](LICENSE).
