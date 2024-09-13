# Testing asynchronous code

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Validate whether your code causes expected events to happen.

## Overview

The testing library integrates with Swift concurrency, meaning that in many
situations you can test asynchronous code using standard Swift
features.  Mark your test function as `async` and, in the function
body, `await` any asynchronous interactions:

```swift
@Test func priceLookupYieldsExpectedValue() async {
  let mozarellaPrice = await unitPrice(for: .mozarella)
  #expect(mozarellaPrice == 3)
}
```

In more complex situations you can use ``Confirmation`` to discover whether an
expected event happens.

### Confirm that an event happens

Call ``confirmation(_:expectedCount:isolation:sourceLocation:_:)-5mqz2`` in your
asynchronous test function to create a `Confirmation` for the expected event. In
the trailing closure parameter, call the code under test. Swift Testing passes a
`Confirmation` as the parameter to the closure, which you call as a function in
the event handler for the code under test when the event you're testing for
occurs:

```swift
@Test("OrderCalculator successfully calculates subtotal for no pizzas")
func subtotalForNoPizzas() async {
  let calculator = OrderCalculator()
  await confirmation() { confirmation in
    calculator.successHandler = { _ in confirmation() }
    _ = await calculator.subtotal(for: PizzaToppings(bases: []))
  }
}
```

If you expect the event to happen more than once, set the
`expectedCount` parameter to the number of expected occurrences. The
test passes if the number of occurrences during the test matches the
expected count, and fails otherwise.

You can also pass a range to ``confirmation(_:expectedCount:isolation:sourceLocation:_:)-6bkl6``
if the exact number of times the event occurs may change over time or is random:

```swift
@Test("Customers bought sandwiches")
func boughtSandwiches() async {
  await confirmation(expectedCount: 0 ..< 1000) { boughtSandwich in
    var foodTruck = FoodTruck()
    foodTruck.orderHandler = { order in
      if order.contains(.sandwich) {
        boughtSandwich()
      }
    }
    await FoodTruck.operate()
  }
}
```

In this example, there may be zero customers or up to (but not including) 1,000
customers who order sandwiches. Any [range expression](https://developer.apple.com/documentation/swift/rangeexpression)
can be used:

| Range Expression | Usage |
|-|-|
| `1...` | If an event must occur _at least_ once |
| `5...` | If an event must occur _at least_ five times |
| `1 ... 5` | If an event must occur at least once, but not more than five times |
| `0 ..< 100` | If an event may or may not occur, but _must not_ occur more than 99 times |

### Confirm that an event doesn't happen

To validate that a particular event doesn't occur during a test,
create a `Confirmation` with an expected count of `0`:

```swift
@Test func orderCalculatorEncountersNoErrors() async {
  let calculator = OrderCalculator()
  await confirmation(expectedCount: 0) { confirmation in
    calculator.errorHandler = { _ in confirmation() }
    calculator.subtotal(for: PizzaToppings(bases: []))
  }
}
```
