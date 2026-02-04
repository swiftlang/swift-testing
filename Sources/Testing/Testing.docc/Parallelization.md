# Running tests serially or in parallel

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Control whether tests run serially or in parallel.

## Overview

By default, tests run in parallel with respect to each other. Parallelization is
accomplished by the testing library using task groups, and tests generally all
run in the same process. The number of tests that run concurrently is controlled
by the Swift runtime.

## Disable parallelization

Parallelization can be disabled on a per-function or per-suite basis using the
``Trait/serialized`` trait:

```swift
@Test(.serialized, arguments: Food.allCases) func prepare(food: Food) {
  // This function will be invoked serially, once per food, because it has the
  // .serialized trait.
}

@Suite(.serialized) struct FoodTruckTests {
  @Test(arguments: Condiment.allCases) func refill(condiment: Condiment) {
    // This function will be invoked serially, once per condiment, because the
    // containing suite has the .serialized trait.
  }

  @Test func startEngine() async throws {
    // This function will not run while refill(condiment:) is running. One test
    // must end before the other will start.
  }
}
```

When added to a parameterized test function, this trait causes that test to run
its cases serially instead of in parallel. When applied to a non-parameterized
test function, this trait has no effect. When applied to a test suite, this
trait causes that suite to run its contained test functions and sub-suites
serially instead of in parallel.

The `.serialized` trait is recursively applied: if it is applied to a suite, any
parameterized tests or test suites contained in that suite are also serialized
(as are any tests contained in those suites, and so on.)

This trait doesn't affect the execution of a test relative to its peers or to
unrelated tests. This trait has no effect if test parallelization is globally
disabled (by, for example, passing `--no-parallel` to the `swift test` command.)

## Serialize tests across multiple files

It may be desirable to organize tests across multiple files while preserving the
serialization of a test suite. For example, consider a scenario where you spin
up a live database for integration testing. You may want to have a large suite
of tests across many files use that same database, but concurrent access to the
database could cause test failures. To achieve this, you can mark a test suite
as `.serialized` and extend that type across your various files. Using the fact
that `.serialized` is recursively applied, you can even put your tests in
sub-suites.

- `FoodTruckDatabaseTests.swift`
  ```swift
  @Suite(.serialized) struct FoodTruckDatabaseTests {}
  ```
- `FoodTruckDatabaseTests+Writing.swift`
  ```swift
  extension FoodTruckDatabaseTests {
    @Test func insertOrder() { /* ... */ }
    @Test func updateOrder() { /* ... */ }
    @Test func deleteOrder() { /* ... */ }
  }
  ```
- `FoodTruckDatabaseTests+Reading.swift`
  ```swift
  extension FoodTruckDatabaseTests {
    @Suite struct ReadingTests {
      @Test func fetchOrder() { /* ... */ }
      @Test func fetchMenu() { /* ... */ }
      @Test func fetchIngredients() { /* ... */ }
    }
  }
  ```

In the example above, all the test functions in the
`FoodTruckDatabaseTests` extension and in `ReadingTests` will run
serially with respect to each other because they are eventually contained
within a test suite which is declared `.serialized`.
