# Debugging Swift Testing on the Commandline using LLDB

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2026 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

For most cases, `swift test` is sufficient to build and run tests. The
instructions below are for when you need to attach LLDB to debug test code
directly. Doing this differs significantly between Darwin and non-Darwin
platforms.

## Darwin Platforms

On Darwin, SwiftPM packages tests into xctest bundles. These bundles are not
directly executable and must be run using the `swiftpm-testing-helper` tool.

### swiftpm-testing-helper

The helper is located within the toolchain:

```sh
# Xcode toolchain
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/libexec/swift/pm/swiftpm-testing-helper

# Custom toolchain
/path/to/toolchain/usr/libexec/swift/pm/swiftpm-testing-helper
```

Required arguments:

1. `--test-bundle-path`: Path to the test bundle executable (e.g.,
   `MyTests.xctest/Contents/MacOS/MyTests`)
2. `--testing-library swift-testing`: Specifies that Swift Testing should be
   used.

Additional `swift test` arguments (such as `--filter`) can also be passed. Run
`swift test --help` for the full list of available options.

### Example: Debugging with LLDB

```sh
lldb -- /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/libexec/swift/pm/swiftpm-testing-helper \
  --test-bundle-path MyTests.xctest/Contents/MacOS/MyTests \
  --testing-library swift-testing
```

This launches LLDB with the testing helper configured to run your test bundle.
You can then set breakpoints and debug your tests normally.

### How Swift Testing Is Linked

Swift Testing ships in two forms: Testing.framework and libTesting.dylib. The
compiler you use to build your test bundle determines which library it links
against. At runtime, the dynamic linker must find the matching library. Problems
occur when the build-time and runtime environments don't match—for example, if
you build with a custom toolchain but run with system libraries, or vice versa.

If you encounter missing symbols or unexpected behavior, export the environment
variables `DYLD_LIBRARY_PATH` or `DYLD_FRAMEWORK_PATH` as appropriate to point
to the correct location.

## Non-Darwin Platforms

On non-Darwin platforms, SwiftPM builds test targets as standalone executables
rather than bundles. You can debug them directly:

```sh
lldb -- .build/debug/MyPackagePackageTests.xctest
```

### Double-Invocation Gotcha

When using Swift Testing on non-Darwin, `swift test` invokes the test binary
twice:

1. **First invocation**: Runs XCTest-based tests via `XCTestMain()`
2. **Second invocation**: Runs Swift Testing tests by passing
   `--testing-library swift-testing`

This is an internal SwiftPM implementation detail. When debugging, you likely
want to skip the XCTest invocation and run Swift Testing directly.

### Example: Debugging with LLDB

To debug only Swift Testing tests, pass `--testing-library` explicitly:

```sh
lldb -- .build/debug/MyPackagePackageTests.xctest --testing-library swift-testing
```

### Passing Arguments

Arguments such as `--filter` are passed through to Swift Testing directly. Run
`swift test --help` for the full list of available options.
