# Expectations and confirmations

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023–2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Check for expected values, outcomes, and asynchronous events in tests.

## Overview

Use ``expect(_:_:sourceLocation:)`` and
``require(_:_:sourceLocation:)-5l63q`` macros to validate expected
outcomes. To validate that an error is thrown, or _not_ thrown, the
testing library provides several overloads of the macros that you can
use. For more information, see <doc:testing-for-errors-in-swift-code>.

Use a ``Confirmation`` to confirm the occurrence of an
asynchronous event that you can't check directly using an expectation.
For more information, see <doc:testing-asynchronous-code>.

### Validate your code's result

To validate that your code produces an expected value, use
``expect(_:_:sourceLocation:)``. This macro captures the
expression you pass, and provides detailed information when the code doesn't
satisfy the expectation.

```swift
@Test func calculatingOrderTotal() {
  let calculator = OrderCalculator()
  #expect(calculator.total(of: [3, 3]) == 7)
  // Prints "Expectation failed: calculator.total(of: [3, 3]) == 7"
}
```

Your test keeps running after ``expect(_:_:sourceLocation:)`` fails. To stop
the test when the code doesn't satisfy a requirement, use
``require(_:_:sourceLocation:)-5l63q`` instead:

```swift
@Test func returningCustomerRemembersUsualOrder() throws {
  let customer = try #require(Customer(id: 123))
  // The test runner doesn't reach this line if the customer is nil.
  #expect(customer.usualOrder.countOfItems == 2)
}
```

``require(_:_:sourceLocation:)-5l63q`` throws an instance of
``ExpectationFailedError`` when your code fails to satisfy the requirement.

### Decide between an expectation and a requirement

``expect(_:_:sourceLocation:)`` and ``require(_:_:sourceLocation:)-5l63q``
check the same kinds of conditions, but they differ in what happens when a
check fails:

- ``expect(_:_:sourceLocation:)`` records an issue and then _continues_
  running the rest of the test. Use it when a single failed check doesn't
  prevent the remaining checks in the test from producing meaningful results,
  so that one test run can report several independent failures at once.
- ``require(_:_:sourceLocation:)-5l63q`` records an issue and then throws an
  error, which _ends_ the current test. Because it throws, you call it with
  `try`. Use it when the rest of the test can't run meaningfully unless the
  condition holds, to avoid reporting a cascade of failures that all stem from
  the same root cause.

As a rule of thumb, reach for ``expect(_:_:sourceLocation:)`` by default, and
switch to ``require(_:_:sourceLocation:)-5l63q`` when continuing the test after
the failure would be pointless or misleading. For example, if you fetch a value
and every later check depends on it, require the value so that the test stops at
the source of the problem instead of producing further failures that the
original failure caused.

The same distinction applies when you work with optionals.
``require(_:_:sourceLocation:)-6w9oo`` unwraps an optional and returns its
value, or records an issue and ends the test if the value is `nil`, which lets
you use the unwrapped value safely in the rest of the test. If you only want to
check that a value isn't `nil` without using it afterward, and you want the test
to keep running, use ``expect(_:_:sourceLocation:)`` instead.

## Topics

### Checking expectations

- ``expect(_:_:sourceLocation:)``
- ``require(_:_:sourceLocation:)-5l63q``
- ``require(_:_:sourceLocation:)-6w9oo``

### Checking that errors are thrown

- <doc:testing-for-errors-in-swift-code>
- ``expect(throws:_:sourceLocation:performing:)-1hfms``
- ``expect(throws:_:sourceLocation:performing:)-7du1h``
- ``expect(_:sourceLocation:performing:throws:)``
- ``require(throws:_:sourceLocation:performing:)-7n34r``
- ``require(throws:_:sourceLocation:performing:)-4djuw``
- ``require(_:sourceLocation:performing:throws:)``

### Checking how processes exit

- <doc:exit-testing>
- ``expect(processExitsWith:observing:_:sourceLocation:performing:)``
- ``require(processExitsWith:observing:_:sourceLocation:performing:)``
- ``ExitStatus``
- ``ExitTest``

### Confirming that asynchronous events occur

- <doc:testing-asynchronous-code>
- ``confirmation(_:expectedCount:isolation:sourceLocation:_:)-5mqz2``
- ``confirmation(_:expectedCount:isolation:sourceLocation:_:)-l3il``
- ``Confirmation``

### Retrieving information about checked expectations

- ``Expectation``
- ``ExpectationFailedError``

### Representing source locations

- ``SourceLocation``
<!-- - ``sourceLocation()`` -->
<!-- - ``SourceContext`` -->
<!-- - ``Backtrace`` -->
