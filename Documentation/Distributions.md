# Obtaining Swift Testing

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

There are multiple ways to obtain Swift Testing, and they have different
tradeoffs to consider. This document discusses the various ways Swift Testing is
distributed and offers recommended workflows.

## Distribution locations

Swift Testing is distributed in the following places:

* In [Swift.org toolchains][install], versions 6.0 and later (for
  [supported platforms][]), as a dynamic library.
* In Apple’s [Xcode IDE][], versions 16.0 and later, as a framework.
* In Apple’s [Command Line Tools for Xcode package][], versions 16.0 and later,
  as a framework.

The locations above are considered **built-in** because they're included with a
larger collection of software (such as a toolchain, IDE, or system package) and
consist of _pre-compiled_ copies of the `Testing` module, its associated runtime
libraries, and its macro plugin.

> [!IMPORTANT]
> Prefer using a built-in copy of Swift Testing unless you're making changes to
> Swift Testing itself.

Swift Testing is also available as a Swift **package library product** from the
[swiftlang/swift-testing][swift-testing] repository. This copy is _not_
considered built-in because it must be downloaded and compiled separately by
each client. The package version is generally considered to have a lower level
of support than the built-in copies above due to the [known caveats][caveats]
described in the following section.

## Caveats when using Swift Testing as a package

Although Swift Testing is available as a Swift package and you _can_ declare a
dependency on [swift-testing][] to use it, doing so is not generally recommended
because it has several downsides:

* **It requires building the Swift Testing runtime library.** This increases
  your build time, and since builds for testing are typically for debug
  configuration, it will not include performance optimizations.
* **It requires building Swift Testing’s macro plugin.** This also increases
  build time, especially because it often requires building [SwiftSyntax][] as
  well. (SwiftSyntax now offers [prebuilt copies][prebuilt-swift-syntax], but
  Swift Testing doesn't always declare a dependency on one of the prebuilt tags,
  circumventing this time-saver.) Additionally, the locally-built macro plugin
  and SwiftSyntax will be built for debug, without optimizations.
* **It may not integrate as well with spporting tools/IDEs as a built-in copy.**
  Tools which integrate with Swift Testing such as Swift Package Manager or
  Apple's Xcode IDE often optimize for the copy included in the same
  distribution. Some features may not work as well or be missing entirely when
  using Swift Testing as a package.
* **It may encounter build failures when another package uses Swift
  Testing.** If you use Swift Testing as a package, but you depend on a library
  from another package which uses a built-in copy of Swift Testing (as this
  document recommends), this can cause build failures:
  * The other package may fail to build non-deterministically due to not having
    a target dependency on the `Testing` target from the locally-built
    [swift-testing][] package.
  * On platforms which don't support a two-level linker namespace, it can fail
    to link due to duplicate defintions for the symbols in the `Testing` library.
* **It may misbehave at runtime.** Even if your build doesn't encounter one of
  the failures mentioned above, mixing built-in and package copies of Swift
  Testing can lead to runtime problems, such as issues (e.g. `#expect` failures)
  being silently ignored.

## When to use Swift Testing as a package

The primary reason Swift Testing is available to be used as a Swift package is
to support its own development. The core contributors regularly develop Swift
Testing by building it locally as a package, following workflows described in
[Contributing][], and its CI builds that way as well.

It's also sometimes helpful to use Swift Testing as a package in order to
validate how changes made to the testing library will impact supporting tools,
or to test changes to both the testing library and a related tool in conjunction
with each other. When using one of these workflows locally, it's important to be
mindful of the [caveats][] above, but during local development it's often
possible to take extra care and control things sufficiently to avoid those
problems.

[install]: https://www.swift.org/install
[supported platforms]: https://github.com/swiftlang/swift-testing/blob/main/README.md#cross-platform-support
[Xcode IDE]: https://developer.apple.com/xcode/
[Command Line Tools for Xcode package]: https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/
[swift-testing]: https://github.com/swiftlang/swift-testing
[SwiftSyntax]: https://github.com/swiftlang/swift-syntax
[Contributing]: https://github.com/swiftlang/swift-testing/blob/main/CONTRIBUTING.md
[caveats]: #caveats-when-using-swift-testing-as-a-package
[prebuilt-swift-syntax]: https://www.swift.org/blog/swift-6.2-released/#macro-build-performance
