# Building with CMake

## Add `swift-testing` to Your Project

Add `swift-testing` with to your project using the standard `FetchContent` or `find_package` mechanism, as appropriate for your project. For example:

```cmake
include(FetchContent)
FetchContent_Declare(SwiftTesting
  GIT_REPOSITORY https://github.com/apple/swift-testing.git
  GIT_TAG main)
FetchContent_MakeAvailable(SwiftTesting)
```

## Define Your Test Executable

To build a test executable using `swift-testing`, define an executable target
of the form `[YOURPROJECT]PackageTests`, set the executable suffix to be
`.swift-testing`, and link to your project targets with `Testing`.

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

## Add an Entry Point

You must define a custom source file with a `@main` entry point. This should be
a separate source file that is included in your test executable's `SOURCES`
list.

The following example uses the SwiftPM entry point:

```swift
import Testing

@main struct Runner {
    static func main() async {
        await Testing.__swiftPMEntryPoint() as Never
    }
}
```
> Note: The entry point is expected to change
to an entry point designed for other build systems prior to `swift-testing` v1.


## Integrate with CTest

To run your test using CTest, add the test using the appropriate command line.

```cmake
include(CTest)
add_test(NAME ExamplePackageTests
  COMMAND ExamplePackageTests)
```
