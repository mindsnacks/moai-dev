# Releasing MoaiSDK

## Prerequisites

- macOS with Xcode installed (for XCFramework builds)
- Android NDK with `ndk-build` in PATH
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated with push and release permissions
- `rsync`, `zip`, `shasum` (included with macOS)

## Creating a release

```
bash release.sh <version>
```

For example:

```
bash release.sh 2.0.3
```

This will:

1. Build XCFrameworks (Debug and Release) for iOS and macOS
2. Zip the XCFrameworks and compute SHA-256 checksums
3. Update `Package.swift` with the new version and checksums
4. Build `libmoai.so` for all Android ABIs (arm64-v8a, armeabi-v7a, x86, x86_64)
5. Package the Android SDK with shared libraries and headers
6. Commit `Package.swift`, tag as `v<version>`, and push
7. Create a GitHub release with auto-generated notes
8. Upload all zip artifacts to the release

## Release artifacts

| Artifact | Contents |
|---|---|
| `MoaiSDK-Debug.zip` | Debug XCFramework (iOS device, iOS simulator, macOS) |
| `MoaiSDK-Release.zip` | Release XCFramework (iOS device, iOS simulator, macOS) |
| `MoaiSDK-Android.zip` | Android shared libraries and headers for all ABIs |

## Swift Package Manager

`Package.swift` at the repo root provides SPM binary targets that point to the XCFramework zips on the GitHub release. The release script updates the version and checksums automatically. Consumers add the package via the repository URL.

## Building individual components

To build just the Apple XCFrameworks:

```
bash xcode/libmoai/build-xcframework.sh -d build
```

To build just the Android libraries:

```
cd ant/libmoai && bash build.sh -a all
```

To zip XCFrameworks and update `Package.swift` without building:

```
bash xcode/libmoai/update-package-swift.sh <version> <build-dir>
```
