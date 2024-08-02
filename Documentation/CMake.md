# Building with CMake

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
`@main` entry point. The following example uses the SwiftPM entry point:

```swift
import Testing

@main struct Runner {
    static func main() async {
        await Testing.__swiftPMEntryPoint() as Never
    }
}
```

> [!WARNING]
> The entry point is expected to change to an entry point designed for other
> build systems prior to the initial stable release of Swift Testing.

## Integrate with CTest

To run your test using CTest, add the test using the appropriate command line.

```cmake
include(CTest)
add_test(NAME ExamplePackageTests
  COMMAND ExamplePackageTests)
```
