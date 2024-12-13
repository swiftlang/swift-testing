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
  // Prints "Expectation failed: (calculator.total(of: [3, 3]) → 6) == 7"
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

### Confirming that asynchronous events occur

- <doc:testing-asynchronous-code>
- ``confirmation(_:expectedCount:isolation:sourceLocation:_:)-5mqz2``
- ``confirmation(_:expectedCount:isolation:sourceLocation:_:)-l3il``
- ``Confirmation``

### Retrieving information about checked expectations

- ``Expectation``
- ``ExpectationFailedError``
- ``CustomTestStringConvertible``

### Representing source locations

- ``SourceLocation``
<!-- - ``_sourceLocation()`` -->
<!-- - ``SourceContext`` -->
<!-- - ``Backtrace`` -->
