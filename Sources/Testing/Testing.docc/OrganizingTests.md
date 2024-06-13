# Organizing test functions with suite types

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Organize tests into test suites.

## Overview

When working with a large selection of test functions, it can be helpful to
organize them into test suites.

A test function can be added to a test suite in one of two ways:

@Comment{ * By placing it in the same file as other test functions. }
* By placing it in a Swift type.
* By placing it in a Swift type and annotating that type with the `@Suite`
   attribute.

The `@Suite` attribute isn't required for the testing library to recognize that
a type contains test functions, but adding it allows customization of a test
suite's appearance in the IDE and at the command line. If a trait such as
``Trait/tags(_:)`` or ``Trait/disabled(_:sourceLocation:)`` is applied to a test
suite, it's automatically inherited by the tests contained in the suite.

In addition to containing test functions and any other members that a Swift type
might contain, test suite types can also contain additional test suites nested
within them. To add a nested test suite type, simply declare an additional type
within the scope of the outer test suite type.

By default, tests contained within a suite run in parallel with each other.
For more information about test parallelization, see <doc:Parallelization>.

### Customize a suite's name

To customize a test suite's name, supply a string literal as an argument to the
`@Suite` attribute:

```swift
@Suite("Food truck tests") struct FoodTruckTests {
  @Test func foodTruckExists() { ... }
}
```

To further customize the appearance and behavior of a test function, use
[traits](doc:Traits) such as ``Trait/tags(_:)``.

## Test functions in test suite types

If a type contains a test function declared as an instance method (that is,
without either the `static` or `class` keyword), the testing library calls
that test function at runtime by initializing an instance of the type, then
calling the test function on that instance. If a test suite type contains
multiple test functions declared as instance methods, each one is called on a
distinct instance of the type. Therefore, the following test suite and test
function:

```swift
@Suite struct FoodTruckTests {
  @Test func foodTruckExists() { ... }
}
```

Are equivalent to:

```swift
@Suite struct FoodTruckTests {
  func foodTruckExists() { ... }

  @Test static func staticFoodTruckExists() {
    let instance = FoodTruckTests()
    instance.foodTruckExists()
  }
}
```

### Constraints on test suite types

When using a type as a test suite, it's subject to some constraints that are
not otherwise applied to Swift types.

#### An initializer may be required

If a type contains test functions declared as instance methods, it must be
possible to initialize an instance of the type with a zero-argument initializer.
The initializer may be any combination of:

- implicit or explicit
- synchronous or asynchronous
- throwing or non-throwing
- `private`, `fileprivate`, `internal`, `package`, or `public`

For example:

```swift
@Suite struct FoodTruckTests {
  var batteryLevel = 100

  @Test func foodTruckExists() { ... } // ✅ OK: The type has an implicit init().
}

@Suite struct CashRegisterTests {
  private init(cashOnHand: Decimal = 0.0) async throws { ... }

  @Test func calculateSalesTax() { ... } // ✅ OK: The type has a callable init().
}

struct MenuTests {
  var foods: [Food]
  var prices: [Food: Decimal]

  @Test static func specialOfTheDay() { ... } // ✅ OK: The function is static.
  @Test func orderAllFoods() { ... } // ❌ ERROR: The suite type requires init().
}
```

The compiler emits an error when presented with a test suite that doesn't
meet this requirement.

### Test suite types must always be available

Although `@available` can be applied to a test function to limit its
availability at runtime, a test suite type (and any types that contain it) must
_not_ be annotated with the `@available` attribute:

```swift
@Suite struct FoodTruckTests { ... } // ✅ OK: The type is always available.

@available(macOS 11.0, *) // ❌ ERROR: The suite type must always be available.
@Suite struct CashRegisterTests { ... }

@available(macOS 11.0, *) struct MenuItemTests { // ❌ ERROR: The suite type's
                                                 // containing type must always
                                                 // be available too.
  @Suite struct BurgerTests { ... }
}
```

The compiler emits an error when presented with a test suite that doesn't
meet this requirement.

#### Classes must be final

The testing library doesn't support inheritance between test suite
types. When using a class as a test suite type, it may inherit from another
class, but it must be declared `final`:

```swift
@Suite final class FoodTruckTests { ... } // ✅ OK: The class is final.
actor CashRegisterTests: NSObject { ... } // ✅ OK: The actors are implicitly final.
class MenuItemTests { ... } // ❌ ERROR: This class isn't final.
```
