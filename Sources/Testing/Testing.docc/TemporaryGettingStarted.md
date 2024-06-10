# Getting started

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

<!-- NOTE: The voice of this document is directed at the second person ("you")
because it provides instructions the reader must follow directly. -->

Start running tests in a new or existing XCTest-based test target.

## Overview

The testing library has experimental integration with Swift Package Manager's
`swift test` command, and integrates with Xcode 16 Beta and Visual Studio Code
(VS Code). These tools can be used to write and run tests alongside, or in place
of, tests written using XCTest. This document describes how to start using the
testing library to write and run tests.

To learn how to contribute to Swift Testing, see
[Contributing to Swift Testing](https://github.com/apple/swift-testing/blob/main/CONTRIBUTING.md).

### Downloading a development toolchain

A recent **6.0 development snapshot** toolchain is required to use all of the
features of the Swift Testing. Visit [swift.org](http://swift.org/install)
to download and install a toolchain from the section titled **release/6.0**
under **Development Snapshots** on the page for your platform.

Be aware that development snapshot toolchains aren't intended for day-to-day
development and may contain defects that affect the programs built with them.

#### Swift 5.10 or earlier

Swift Testing doesn't support Swift 5.10 or earlier toolchains. You can use a
Swift 6.0 development snapshot toolchain to write tests or validate code which
uses the Swift 5 language mode, however.

### Adding the testing library as a dependency

- Note: When using Xcode 16 Beta, Swift Testing is available automatically and
  the steps in this section aren't required.

In your package's `Package.swift` file, add the testing library as a package
dependency:

```swift
dependencies: [
  .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0"),
],
```

Then, add the package's `Testing` product as a dependency of your test target:

```swift
.testTarget(
  name: "FoodTruckTests",
  dependencies: [
    "FoodTruck",
    .product(name: "Testing", package: "swift-testing"),
  ]
)
```

### Specifying minimum deployment targets

To ensure that your package's deployment targets meet or exceed those of the
testing library, you may also need to specify minimum deployment targets for
iOS, macOS, tvOS, visionOS, and/or watchOS, depending on which platforms your
package supports:

```swift
platforms: [
  .iOS(.v13), .macOS(.v10_15), .macCatalyst(.v13), .tvOS(.v13), .visionOS(.v1), .watchOS(.v6)
],
```

### Writing tests

You can now add additional Swift source files to your package's test target that
contain those tests, written using the testing library, that you want to run
when you invoke `swift test` from the command line or click the
Product&nbsp;&rarr;&nbsp;Test menu item in Xcode.

### Configuring the environment

#### Configuring the command-line

When running macOS, the system will use the Swift toolchain included with Xcode
by default. To instruct the system to use the development toolchain you just
installed, enter the following command to configure the current command-line
session:

```sh
export TOOLCHAINS=swift
```

#### Configuring Xcode

In Xcode, open the **Xcode** menu, then the Toolchains submenu, and select the
development toolchain from the list of toolchains presented to you — it will
be presented with a name such as "Swift Development Toolchain 2023-01-01 (a)".

#### Configuring VS Code

Follow the instructions under
 [Install the Extension](https://www.swift.org/documentation/articles/getting-started-with-vscode-swift.html#install-the-extension)
of the
[Getting Started with Swift in VS Code](https://www.swift.org/documentation/articles/getting-started-with-vscode-swift.html)
guide.

### Running tests

#### Running from the command line

Navigate to the directory containing your package and run the following command:

```sh
swift test
```

Swift Package Manager will build and run a test target that uses the testing
library as well as a separate target that uses XCTest. To only run tests written
using the testing library, pass `--disable-xctest` as an additional argument to
the `swift test` command.

- Note: If your package does not explicitly list the testing library as a
  dependency, pass `--enable-experimental-swift-testing` to the `swift test`
  command to ensure your tests are run.

#### Running tests in Xcode 16 Beta

Click the Product → Test menu item, or press ⌘+U, to run Swift Testing tests
using Xcode 16 Beta.

#### Running tests in VS Code

See the [Test Explorer](https://www.swift.org/documentation/articles/getting-started-with-vscode-swift.html#test-explorer)
section of
[Getting Started with Swift in VS Code](https://www.swift.org/documentation/articles/getting-started-with-vscode-swift.html).

## Topics

- ``XCTestScaffold``
