# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`UserKitFirebase` is the **Firebase provider adapter** for UserKit — the provider-neutral "current authenticated user" core (separate package, local clone at `../user-kit`). This package `import`s `UserKit` and conforms concrete types (`FirebaseUserService`, `FirebaseUserStorage`, `FirebaseUserSynchronizer`, `FirebaseUserInfo`/`Session`/`Profile`) to its protocols. The dependency only ever points core → nothing / adapter → core; never add UserKit-Firebase code to the core.

## Build & test

**`swift build` and `swift test` do NOT work here.** The package is iOS-only (`.iOS(.v18)`) and depends on the iOS-only FirebaseUI-iOS graph, but the SwiftPM CLI builds for the macOS host and fails on platform constraints. Build and test through an iOS destination instead:

- Build: `xcodebuild build -scheme UserKitFirebase -destination 'platform=iOS Simulator,name=iPhone 17'`
- Test: `xcodebuild test -scheme UserKitFirebase -destination 'platform=iOS Simulator,name=iPhone 17'`
- Or use Xcode / the XcodeBuildMCP tools. First cold build resolves the full Firebase graph and is slow.
- Tests use **swift-testing** (`import Testing`, `@Suite`/`@Test`/`#expect`), not XCTest.
- Format: `swift format --in-place --recursive Sources Tests` (config in `.swift-format`; lint-only: `swift format lint --recursive Sources Tests`). `public extension` is intentional — the `NoAccessLevelOnExtensionDeclaration` rule is disabled.

## Concurrency dialect (do not break)

Every target sets these Swift settings, and any new target must mirror them:

```swift
swiftSettings: [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]
```

They match the core package and the consumer app's "Approachable Concurrency" dialect so async-closure isolation lines up across the package boundary. Drop them and protocol conformances mismatch (`nonisolated(nonsending)` vs `@concurrent`).

## Firebase interop gotchas

- `FirebaseAuth` is an Objective-C SDK that predates strict concurrency. The `@preconcurrency import FirebaseAuth`, `nonisolated(unsafe)` stored SDK objects, `@unchecked Sendable` value wrappers, and the `SendableClaims` struct that ferries `[String: Any]` across a continuation are all **deliberate, narrow escapes** at that boundary — not cleanup targets.
- Auth-state callbacks are bridged to `AsyncSequence` via `AsyncStream`; always remove the listener in `continuation.onTermination` so the stream is cancel-safe (`User.deinit` calls `dispose()`).
- `FirebaseUserStorage.store`/`clear` are **intentional no-ops** — Firebase owns session persistence. `fetch()` force-refreshes the ID token and reads claims; don't "implement" the no-ops.
- `FirebaseUserInfo.role` overrides the core default (`nil`) with the JWT `role` custom claim, which is what core `isAdmin` (`role == "admin"`) reads. The adapter surfaces the raw string only; role policy lives in the core.

## Contract with the core (`../user-kit`)

- Conform to `UserService.singIn()` — the name is **misspelled on purpose** in the core protocol; don't "fix" it (breaking change across every adapter).
- `User.firebaseAuthService` (extension here) downcasts the core's `public var service` to hand the app the underlying FirebaseAuthSwiftUI `AuthService`.
- Full adapter contract: see `../user-kit/CLAUDE.md` and its `using-userkit` skill (`.claude/skills/using-userkit/references/firebase-adapter.md`).

## Dependencies

- Pin provider SDK versions to exactly what the consumer app already resolves (`firebase-ios-sdk` exact `12.12.1`; `FirebaseUI-iOS` pinned to a revision because the upstream branch was deleted — see the comment in `Package.swift`). Don't bump casually; it perturbs the app's dependency graph.
- `Package.resolved` is gitignored (not committed) — this is a library.
