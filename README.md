# Swift Testing

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Swift Testing is a package with expressive and intuitive APIs that make testing
your Swift code a breeze.

## Feature overview

### Clear, expressive API

Swift Testing has a clear and expressive API built using macros, so you can
declare complex behaviors with a small amount of code. The `#expect` API uses
Swift expressions and operators, and captures the evaluated values so you can
quickly understand what went wrong when a test fails.

```swift
@Test func helloWorld() {
  let greeting = "Hello, world!"
  #expect(greeting == "Hello") // Expectation failed: (greeting → "Hello, world!") == "Hello"
}
```

### Custom test behaviors

You can customize the behavior of tests or test suites using traits specified in
your code. Traits can describe the runtime conditions for a test, like which
device a test should run on, or limit a test to certain operating system
versions. Traits can also help you use continuous integration effectively by
specifying execution time limits for your tests.

```swift
@Test(.enabled(if: AppFeatures.isCommentingEnabled))
func videoCommenting() async throws {
    let video = try #require(await videoLibrary.video(named: "A Beach"))
    #expect(video.comments.contains("So picturesque!"))
}
```

### Easy and flexible organization

Swift Testing provides many ways to keep your tests organized. Structure
related tests using a hierarchy of groups and subgroups. Apply tags to flexibly
manage, edit, and run tests with common characteristics across your test suite,
like tests that target a specific device or use a specific module. You can also
give tests a descriptive name so you know what they’re doing at a glance.

```swift
@Test("Check video metadata",
      .tags(.metadata))
func videoMetadata() {
    let video = Video(fileName: "By the Lake.mov")
    let expectedMetadata = Metadata(duration: .seconds(90))
    #expect(video.metadata == expectedMetadata)
}
```

### Scalable coverage and execution

Parameterized tests help you run the same test over a sequence of values so you
can write less code. And all tests integrate seamlessly with Swift Concurrency
and run in parallel by default.

```swift
@Test("Continents mentioned in videos", arguments: [
    "A Beach",
    "By the Lake",
    "Camping in the Woods"
])
func mentionedContinents(videoName: String) async throws {
    let videoLibrary = try await VideoLibrary()
    let video = try #require(await videoLibrary.video(named: videoName))
    #expect(video.mentionedContinents.count <= 3)
}
```

### Cross-platform support

Swift Testing works on all major platforms supported by Swift, including Apple
platforms, Linux, and Windows, so your tests can behave more consistently when
moving between platforms. It’s developed as open source and discussed on the
[Swift Forums](https://forums.swift.org/c/related-projects/swift-testing) so the
very best ideas, from anywhere, can help shape the future of testing in Swift.

The table below describes the current level of support that Swift Testing has
for various platforms:

| **Platform** | **CI Status (6.0)** | **CI Status (main)** | **Support Status** |
|---|:-:|:-:|---|
| **macOS** | [![Build Status](https://ci.swift.org/buildStatus/icon?job=swift-testing-main-swift-6.0-macos)](https://ci.swift.org/job/swift-testing-main-swift-6.0-macos/) | [![Build Status](https://ci.swift.org/buildStatus/icon?job=swift-testing-main-swift-main-macos)](https://ci.swift.org/view/Swift%20Packages/job/swift-testing-main-swift-main-macos/) | Supported |
| **iOS** | | | Supported |
| **watchOS** | | | Supported |
| **tvOS** | | | Supported |
| **visionOS** | | | Supported |
| **Ubuntu 22.04** | [![Build Status](https://ci.swift.org/buildStatus/icon?job=swift-testing-main-swift-6.0-linux)](https://ci.swift.org/job/swift-testing-main-swift-6.0-linux/) | [![Build Status](https://ci.swift.org/buildStatus/icon?job=swift-testing-main-swift-main-linux)](https://ci.swift.org/view/Swift%20Packages/job/swift-testing-main-swift-main-linux/) | Supported |
| **Windows** | | [![Build Status](https://ci-external.swift.org/buildStatus/icon?job=swift-testing-main-swift-main-windows)](https://ci-external.swift.org/job/swift-testing-main-swift-main-windows/) | Supported |

### Works with XCTest

If you already have tests written using XCTest, you can run them side-by-side
with newer tests written using Swift Testing. This helps you migrate tests
incrementally, at your own pace.

## Documentation

> [!IMPORTANT]
> This package is under active, ongoing development and requires a recent
> **6.0 development snapshot** toolchain. Its contents and interfaces are still
> considered experimental at this time and may change. See this
> [Forum post](https://forums.swift.org/t/an-update-on-swift-testing-progress-and-stable-release-plans/71455)
> for details about stable release plans.

Detailed documentation for Swift Testing can be found on the
[Swift Package Index](https://swiftpackageindex.com/apple/swift-testing/main/documentation/testing).
There, you can delve into comprehensive guides, tutorials, and API references to
make the most out of this package. To try it yourself, see
[Getting Started](https://swiftpackageindex.com/apple/swift-testing/main/documentation/testing/temporarygettingstarted).

Other documentation resources for this project can be found in the
[README](https://github.com/apple/swift-testing/blob/main/Documentation/README.md) 
of the `Documentation/` subdirectory.
