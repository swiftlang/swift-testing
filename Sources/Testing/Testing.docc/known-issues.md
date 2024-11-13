# Known issues

<!--
This source file is part of the Swift.org open source project

Copyright © 2023–2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Mark issues as known when running tests.

## Overview

The testing library provides several functions named `withKnownIssue()` that
you can use to mark issues as known. Use them to inform the testing library that
a test should not be marked as failing if only known issues are recorded.

### Mark an expectation failure as known

Consider a test function with a single expectation:

```swift
@Test func grillHeating() throws {
  var foodTruck = FoodTruck()
  try foodTruck.startGrill()
  #expect(foodTruck.grill.isHeating) // ❌ Expectation failed
}
```

If the value of the `isHeating` property is `false`, `#expect` will record an
issue. If you cannot fix the underlying problem, you can surround the failing
code in a closure passed to `withKnownIssue()`:

```swift
@Test func grillHeating() throws {
  var foodTruck = FoodTruck()
  try foodTruck.startGrill()
  withKnownIssue("Propane tank is empty") {
    #expect(foodTruck.grill.isHeating) // Known issue
  }
}
```

The issue recorded by `#expect` will then be considered "known" and the test
will not be marked as a failure. You may include an optional comment to explain
the problem or provide context.

### Mark a thrown error as known

If an `Error` is caught by the closure passed to `withKnownIssue()`, the issue
representing that caught error will be marked as known. Continuing the previous
example, suppose the problem is that the `startGrill()` function is throwing an
error. You can apply `withKnownIssue()` to this situation as well:

```swift
@Test func grillHeating() {
  var foodTruck = FoodTruck()
  withKnownIssue {
    try foodTruck.startGrill() // Known issue
    #expect(foodTruck.grill.isHeating)
  }
}
```

Because all errors thrown from the closure are caught and interpreted as known
issues, the `withKnownIssue()` function is not throwing. Consequently, any
subsequent code which depends on the throwing call having succeeded (such as the
`#expect` after `startGrill()`) must be included in the closure to avoid
additional issues.

### Match a specific issue

By default, `withKnownIssue()` considers all issues recorded while invoking the
body closure known. If multiple issues may be recorded, you can pass a trailing
closure labeled `matching:` which will be called once for each recorded issue
to determine whether it should be treated as known:

```swift
@Test func batteryLevel() throws {
  var foodTruck = FoodTruck()
  try withKnownIssue {
    let batteryLevel = try #require(foodTruck.batteryLevel) // Known
    #expect(batteryLevel >= 0.8) // Not considered known
  } matching: { issue in
    guard case .expectationFailed(let expectation) = issue.kind else {
      return false
    }
    return expectation.isRequired
  }
}
```

### Resolve a known issue

If there are no issues recorded while calling `function`, `withKnownIssue()`
will record a distinct issue about the lack of any issues having been recorded.
This notifies you that the underlying problem may have been resolved so that you
can investigate and consider removing `withKnownIssue()` if it's no longer
necessary.

### Handle a nondeterministic failure

If `withKnownIssue()` sometimes succeeds but other times records an issue
indicating there were no known issues, this may indicate a nondeterministic
failure or a "flaky" test.

If the underlying problem only occurs in certain circumstances, consider
including a precondition. For example, if the grill only fails to heat when
there's no propane, you can pass a trailing closure labeled `when:` which
determines whether issues recorded in the body closure should be considered
known:

```swift
@Test func grillHeating() throws {
  var foodTruck = FoodTruck()
  try foodTruck.startGrill()
  withKnownIssue {
    // Only considered known when hasPropane == false
    #expect(foodTruck.grill.isHeating)
  } when: {
    !hasPropane
  }
}
```

If the underlying problem is truly nondeterministic, you may acknowledge this
and instruct `withKnownIssue()` to not record an issue indicating there were no
known issues by passing `isIntermittent: true`:

```swift
@Test func grillHeating() throws {
  var foodTruck = FoodTruck()
  try foodTruck.startGrill()
  withKnownIssue(isIntermittent: true) {
    #expect(foodTruck.grill.isHeating)
  }
}
```

## Topics

### Recording known issues in tests

- ``withKnownIssue(_:isIntermittent:sourceLocation:_:)``
- ``withKnownIssue(_:isIntermittent:isolation:sourceLocation:_:)``
- ``withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)``
- ``withKnownIssue(_:isIntermittent:isolation:sourceLocation:_:when:matching:)``
- ``KnownIssueMatcher``

### Describing a failure or warning

- ``Issue``
