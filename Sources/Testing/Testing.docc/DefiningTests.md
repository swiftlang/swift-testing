# Defining test functions

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Define a test function to validate that code is working correctly.

## Overview

Defining a test function for a Swift package or project is straightforward.

### Import the testing library

To import the testing library, add the following to the Swift source file that
contains the test:

```swift
import Testing
```

- Note: Only import the testing library into a test target. Importing the
  testing library into an application, library, or binary target isn't
  supported or recommended. Test functions aren't stripped from binaries when
  building for release, so logic and fixtures of a test may be visible to anyone
  who inspects a build product that contains a test function.

### Declare a test function

To declare a test function, write a Swift function declaration that doesn't
take any arguments, then prefix its name with the `@Test` attribute:

```swift
@Test func `Food truck exists`() {
  // Test logic goes here.
}
```

This test function can be present at file scope or within a type. A type
containing test functions is automatically a _test suite_ and you can optionally
annotate it with the `@Suite` attribute. For more information about suites, see
<doc:OrganizingTests>.

Note that, while this function is a valid test function, it doesn't actually
perform any action or test any code. To check for expected values and outcomes
in test functions, add [expectations](doc:Expectations) to the test function.

### Customize a test's name

To customize a test function's name as presented in an IDE or at the command
line, supply a string literal as an argument to the `@Test` attribute:

```swift
@Test("Food truck exists") func foodTruckExists() { ... }
```

To further customize the appearance and behavior of a test function, use
[traits](doc:Traits) such as ``Trait/tags(_:)``.

### Write concurrent or throwing tests

As with other Swift functions, test functions can be marked `async` and `throws`
to annotate them as concurrent or throwing, respectively. If a test is only safe
to run in the main actor's execution context (that is, from the main thread of
the process), it can be annotated `@MainActor`:

```swift
@Test @MainActor func `Food truck exists`() async throws { ... }
```

### Limit the availability of a test

If a test function can only run on newer versions of an operating system or of
the Swift language, use the `@available` attribute when declaring it. Use the
`message` argument of the `@available` attribute to specify a message to log if
a test is unable to run due to limited availability:

```swift
@available(macOS 11.0, *)
@available(swift, introduced: 8.0, message: "Requires Swift 8.0 features to run")
@Test func foodTruckExists() { ... }
```
