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

<!-- TODO: discuss .serialized(for:) -->

## Disabling parallelization

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

This trait is recursively applied: if it is applied to a suite, any
parameterized tests or test suites contained in that suite are also serialized
(as are any tests contained in those suites, and so on.)

This trait doesn't affect the execution of a test relative to its peers or to
unrelated tests. This trait has no effect if test parallelization is globally
disabled (by, for example, passing `--no-parallel` to the `swift test` command.)

## Constraints on concurrent tests

Parallel test execution is usually desirable, but some tests can't safely run
at the same time as other tests. Common causes include:

- Mutable global or static state, such as a shared `FoodTruck.shared` value that
  more than one test reads and writes.
- External resources that assume exclusive access, such as a temporary file at a
  fixed path or a local server bound to a fixed port.
- Code that must run on a specific actor or thread even when Swift's
  concurrency checking reports no data races. Exclusive access can still be
  required for correct behavior.

When two tests interfere with each other only under parallel execution, the
failure is often intermittent and hard to reproduce. Prefer fixing the shared
state so that each test owns what it needs. If that isn't practical yet, use
``Trait/serialized`` so the conflicting tests don't overlap.

If tests only need to coordinate access to a particular actor rather than run
one after another, isolating a test to a global actor can be enough without
``Trait/serialized``. For example, annotate a test with `@MainActor` when it
must run on the main actor:

```swift
@Test @MainActor func licenseIsValid() {
  // Runs on the main actor, so it can safely call main-actor-isolated APIs.
  #expect(FoodTruck.shared.isLicensed)
}
```

You can also run a smaller region of a test on the main actor with
[`MainActor.run(resultType:body:)`](https://developer.apple.com/documentation/swift/mainactor/run(resulttype:body:)).
For more information about marking tests `async`, `throws`, or actor-isolated,
see <doc:DefiningTests>.

- Note: If your tests need ``Trait/serialized`` or global-actor isolation
  because product code exposes unconstrained shared mutable state, that is
  often a signal that non-test clients can hit the same interference. Consider
  making the API safer—for example by encapsulating the state in an actor or by
  letting callers supply an isolated dependency—so both tests and production
  code are easier to reason about.

If you are migrating from XCTest, see <doc:MigratingFromXCTest> for an example
of annotating a suite with ``Trait/serialized`` when shared state previously
relied on XCTest's sequential default.
