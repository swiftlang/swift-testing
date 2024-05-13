# Expectations and confirmations

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023–2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Check for expected values, outcomes, and events in tests.

## Overview

Use ``expect(_:_:sourceLocation:)`` and
``require(_:_:sourceLocation:)-5l63q`` macros to validate expected
outcomes.  To validate that an error is thrown, or _not_ thrown, the
testing library provides several overloads of the macros that you can
use.  Use a ``Confirmation`` to confirm the occurrence of an
asynchronous event that you can't check directly using an expectation.

### Validate your code's result

To validate that your code produces an expected value, use
`#expect()`.  `#expect()` captures the expression you pass, and
provides detailed information when the code doesn't satisfy the
expectation:

```swift
class OrderCalculator {
    func total(of subtotals: [Int]) -> Int {
        return subtotals.reduce(1) { partialResult, subtotal in
            partialResult + subtotal
        }
    }
}

@Test func calculatingOrderTotal() {
    let calculator = OrderCalculator()
    #expect(calculator.total(of: [3, 3]) == 6)
    // Prints "Expectation failed: (calculator.total(of: [3, 3]) → 7) == 6"
}
```

Your test keeps running after `#expect()` fails.  To stop the test
when the code doesn't satisfy a requirement, use `#require()` instead:

```swift
@Test func returningCustomerRemembersUsualOrder() throws {
    let customer = Customer(id: 123)
    try #require(customer)
    #expect(customer?.usualOrder?.countOfItems == 2) // The test runner doesn't reach this line if the customer is nil.
}
```

`#require()` throws an instance of ``ExpectationFailedError`` when your code
fails to satisfy the requirement.

## Topics

### Checking expectations

- ``expect(_:_:sourceLocation:)``
- ``require(_:_:sourceLocation:)-5l63q``
- ``require(_:_:sourceLocation:)-6w9oo``

### Checking that errors are thrown

- <doc:testing-for-errors-in-swift-code>
- ``expect(throws:_:sourceLocation:performing:)-79piu``
- ``expect(throws:_:sourceLocation:performing:)-1xr34``
- ``expect(_:sourceLocation:performing:throws:)``
- ``expect(throws:_:sourceLocation:performing:)-5lzjz``
- ``require(throws:_:sourceLocation:performing:)-76bjn``
- ``require(throws:_:sourceLocation:performing:)-7v83e``
- ``require(_:sourceLocation:performing:throws:)``
- ``require(throws:_:sourceLocation:performing:)-36uzc``

### Confirming that asynchronous events occur

- ``<doc:testing-asynchronous-code>
- ``confirmation(_:expectedCount:fileID:filePath:line:column:_:)``
- ``Confirmation``

### Retrieving information about checked expectations

- ``Expectation``
- ``ExpectationFailedError``
- ``CustomTestStringConvertible``

### Representing source locations

- ``SourceLocation``
- ``SourceContext``
- ``Backtrace``
