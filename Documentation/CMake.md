# Building with CMake

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

## Add Swift Testing to your project

Add Swift Testing to your project using the standard `FetchContent` or
`find_package` mechanism, as appropriate for your project. For example:

```cmake
include(FetchContent)
FetchContent_Declare(SwiftTesting
  GIT_REPOSITORY https://github.com/swiftlang/swift-testing.git
  GIT_TAG main)
FetchContent_MakeAvailable(SwiftTesting)
```

## Define a test executable

To build a test executable using Swift Testing, define an executable target of
the form `[YOURPROJECT]PackageTests`, set the executable suffix to be
`.swift-testing`, and link to the `Testing` target as well as any project
targets you wish to test.

The following
example shows what this might look like for a hypothetical project called
`Example`:

```cmake
add_executable(ExamplePackageTests
  ExampleTests.swift
  ...)
set_target_properties(ExamplePackageTests PROPERTIES
  SUFFIX .swift-testing)
target_link_libraries(ExamplePackageTests PRIVATE
  Example
  Testing
  ...)
```

When building the test executable, the code you're testing will need to be built
with `-enable-testing`. This should only be enabled for testing, for example:

```cmake
include(CTest)
if(BUILD_TESTING)
  add_compile_options($<$<COMPILE_LANGUAGE:Swift>:-enable-testing>)
endif()
```

## Add an entry point

You must include a source file in your test executable target with a
`@main` entry point. The example main below requires the experimental
`Extern` feature. The declaration of `swt_abiv0_getEntryPoint` could
also be written in a C header file with its own `module.modulemap`.

```swift
typealias EntryPoint = @convention(thin) @Sendable (_ configurationJSON: UnsafeRawBufferPointer?, _ recordHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void) async throws -> Bool

@_extern(c, "swt_abiv0_getEntryPoint")
func swt_abiv0_getEntryPoint() -> UnsafeRawPointer

@main struct Runner {
    static func main() async throws {
        nonisolated(unsafe) let configurationJSON: UnsafeRawBufferPointer? = nil
        let recordHandler: @Sendable (UnsafeRawBufferPointer) -> Void = { _ in }

        let entryPoint = unsafeBitCast(swt_abiv0_getEntryPoint(), to: EntryPoint.self)

        if try await entryPoint(configurationJSON, recordHandler) {
            exit(EXIT_SUCCESS)
        } else {
            exit(EXIT_FAILURE)
        }
    }
}
```

For more information on the input configuration and output records of the ABI entry
point, refer to the [ABI documentation](ABI/JSON.md)

## Integrate with CTest

To run your test using CTest, add the test using the appropriate command line.

```cmake
include(CTest)
add_test(NAME ExamplePackageTests
  COMMAND ExamplePackageTests)
```
