# Swift Testing documentation

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

## API and usage guides

The detailed documentation for Swift Testing can be found on the
[Swift Package Index](https://swiftpackageindex.com/swiftlang/swift-testing/main/documentation/testing).
There, you can delve into comprehensive guides, tutorials, and API references to
make the most out of this package.

This documentation is generated using [DocC](https://github.com/swiftlang/swift-docc)
and is derived from symbol documentation in this project's source code as well
as supplemental content located in the
[`Sources/Testing/Testing.docc/`](https://github.com/swiftlang/swift-testing/tree/main/Sources/Testing/Testing.docc)
directory.

## Vision document and API proposals

The [Vision document](https://github.com/swiftlang/swift-evolution/blob/main/visions/swift-testing.md)
for Swift Testing offers a comprehensive discussion of the project's design
principles and goals.

Feature and API proposals for Swift Testing are stored in the
[swift-evolution](https://github.com/swiftlang/swift-evolution) repository in
the `proposals/testing/` subdirectory, and new proposals should use the
[testing template](https://github.com/swiftlang/swift-evolution/blob/main/proposal-templates/0000-swift-testing-template.md)
there.

## Development and contribution

- The top-level [`README`](https://github.com/swiftlang/swift-testing/blob/main/README.md)
  gives a high-level overview of the project, shows current CI status, lists the
  support status of various platforms, and more.
- [Contributing](https://github.com/swiftlang/swift-testing/blob/main/CONTRIBUTING.md)
  provides guidance for developing and making project contributions.
- [Porting](https://github.com/swiftlang/swift-testing/blob/main/Documentation/Porting.md)
  includes advice and instructions for developers who are porting Swift Testing
  to a new platform.
- [Style Guide](https://github.com/swiftlang/swift-testing/blob/main/Documentation/StyleGuide.md)
  describes this project's guidelines for code and documentation style.
- [SPI groups in Swift Testing](https://github.com/swiftlang/swift-testing/blob/main/Documentation/SPI.md)
  describes when and how the testing library uses Swift SPI.

## Experimental platform support

- Instructions are provided for running tests against a
  [WASI/WebAssembly target](https://github.com/swiftlang/swift-testing/blob/main/Documentation/WASI.md).

## Testing library ABI

The [`ABI`](ABI/) directory contains documents related to Swift Testing's ABI:
that is, parts of its interface that are intended to be stable over time and can
be used without needing to write any code in Swift:

- [`ABI/JSON.md`](ABI/JSON.md) contains Swift Testing's JSON specification that
  can be used by tools to interact with Swift Testing either directly or via the
  `swift test` command-line tool.
- [`ABI/TestContent.md`](ABI/TestContent.md) documents the section emitted by
  the Swift compiler into test products that contains test definitions and other
  metadata used by Swift Testing (and extensible by third-party testing
  libraries.)
