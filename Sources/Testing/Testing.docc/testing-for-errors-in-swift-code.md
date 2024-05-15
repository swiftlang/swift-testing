# Testing for errors in Swift code

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Ensure that your code handles errors in the way you expect.

## Overview

The Swift language provides an idiomatic approach to [error
handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling),
based on throwing errors where your code detects a failure for a
caller to catch and react to.

Write tests for your code that validate the conditions in which the
code throws errors, and the conditions in which it returns without
throwing an error.  Use overrides of the `#expect()` and `#require()`
macros that check for errors.

### Validate that your code throws an expected error

The Swift structure in this example represents a list that accepts any
number of toppings for pizzas in the list.  The API contains a method for
applying a topping to a range of pizzas, and a method for retrieving the
toppings requested for the item at a given index.  Both of these methods
throw errors if their parameters are outside the list's range.

```swift
enum PizzaBase {
    case deepCrust
    case shallowCrust
    case calzone
}

enum Topping {
    case tomato
    case cheese
    case caper
    case anchovy
    case prosciutto
    case pineapple
}

struct PizzaToppings {
    enum PizzaToppingsError : Error {
        case outOfRange
    }

    let pizzas: [PizzaBase]
    var toppings: [Int: [Topping]]

    init(bases: [PizzaBase]) {
        pizzas = bases
        toppings = [Int: [Topping]]()
    }

    mutating func add(topping: Topping, toPizzasIn range: Range<Int>) throws {
        guard Int(range.startIndex) >= 0 && Int(range.endIndex) < pizzas.count else {
            throw PizzaToppingsError.outOfRange
        }
        for index in range {
            if var toppingList = toppings[index] {
                toppingList.append(topping)
                toppings[index] = toppingList
            } else {
                toppings[index] = [topping]
            }
        }
    }

    func toppings(forPizzaAt index: Int) throws -> [Topping] {
        guard index >= 0 && index < pizzas.count else {
            throw PizzaToppingsError.outOfRange
        }
        return toppings[index] ?? []
    }

    // Other methods.
}
```

Create a test function that `throws` and `try` the code under test.
If the code throws an error, then your test fails.

To check that the code under test throws a specific error, or to continue a
longer test function after the code throws an error, pass that error as the
first argument of ``expect(throws:_:sourcelocation:performing:)-1xr34``, and
pass a closure that calls the code under test:

```swift
@Test func cannotAddToppingToPizzaBeforeStartOfList() {
    var order = PizzaToppings(bases: [.calzone, .deepCrust])
    #expect(throws: PizzaToppings.PizzaToppingsError.outOfRange) {
        try order.add(topping: .mozarella, toPizzasIn: -1..<0)
    }
}
```

If the closure completes without throwing an error, the testing library
records an issue.  Other overloads of `#expect()` let you test that
the code throws an error of a given type, or matching an arbitrary
Boolean test.  Similar overloads of `#require()` stop running your
test if the code doesn't throw the expected error.

### Validate that your code doesn't throw an error

Validate that the code under test doesn't throw an error by comparing
the error to `Never`:

```swift
@Test func canAddToppingToPizzaInPositionZero() throws {
    var order = PizzaToppings(bases: [.thinCrust, .thinCrust])
    #expect(throws: Never.self) {
        try order.add(topping: .caper, toPizzasIn: 0..<1)
    }
    #expect(try order.toppings(forPizzaAt: 0) == [.caper])
}
```

If the closure throws an error, the testing library records an issue.
If you need the test to stop if the code throws an error, include the
code inline in the test function instead of wrapping it in an
`#expect(throws:)` block.
