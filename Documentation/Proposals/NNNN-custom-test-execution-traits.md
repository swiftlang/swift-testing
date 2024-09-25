# Custom Test Execution Traits

* Proposal: [SWT-NNNN](NNNN-filename.md)
* Authors: [Stuart Montgomery](https://github.com/stmontgomery)
* Status: **Awaiting review**
* Implementation: [swiftlang/swift-testing#733](https://github.com/swiftlang/swift-testing/pull/733), [swiftlang/swift-testing#86](https://github.com/swiftlang/swift-testing/pull/86)
* Review: ([pitch](https://forums.swift.org/...))

## Introduction

This introduces API which enables a custom `Trait`-conforming type to customize
the execution of test functions and suites, including running code before or
after them.

## Motivation

One of the primary motivations for the trait system in Swift Testing, as
[described in the vision document](https://github.com/swiftlang/swift-evolution/blob/main/visions/swift-testing.md#trait-extensibility),
is to provide a way to customize the behavior of tests which have things in
common. If all the tests in a given suite type need the same custom behavior,
`init` and/or `deinit` (if applicable) can be used today. But if only _some_ of
the tests in a suite need custom behavior, or tests across different levels of
the suite hierarchy need it, traits would be a good place to encapsulate common
logic since they can be applied granularly per-test or per-suite. This aspect of
the vision for traits hasn't been realized yet, though: the `Trait` protocol
does not offer a way for a trait to customize the execution of the tests or
suites it's applied to.

Customizing a test's behavior typically means running code either before or
after it runs, or both. Consolidating common set-up and tear-down logic allows
each test function to be more succinct with less repetitive boilerplate so it
can focus on what makes it unique.

## Proposed solution

At a high level, this proposal entails adding API to the `Trait` protocol
allowing a conforming type to opt-in to customizing the execution of test
behavior. We discuss how that capability should be exposed to trait types below.

### Supporting scoped access

There are different approaches one could take to expose hooks for a trait to
customize test behavior. To illustrate one of them, consider the following
example of a `@Test` function with a custom trait whose purpose is to set mock
API credentials for the duration of each test it's applied to:

```swift
@Test(.mockAPICredentials)
func example() {
  // ...
}

struct MockAPICredentialsTrait: TestTrait { ... }

extension Trait where Self == MockAPICredentialsTrait {
  static var mockAPICredentials: Self { ... }
}
```

In this hypothetical example, the current API credentials are stored via a
static property on an `APICredentials` type which is part of the module being
tested:

```swift
struct APICredentials {
  var apiKey: String

  static var shared: Self?
}
```

One way that this custom trait could customize the API credentials during each
test is if the `Trait` protocol were to expose a pair of method requirements
which were then called before and after the test, respectively:

```swift
public protocol Trait: Sendable {
  // ...
  func setUp() async throws
  func tearDown() async throws
}

extension Trait {
  // ...
  public func setUp() async throws { /* No-op */ }
  public func tearDown() async throws { /* No-op */ }
}
```

The custom trait type could adopt these using code such as the following:

```swift
extension MockAPICredentialsTrait {
  func setUp() {
    APICredentials.shared = .init(apiKey: "...")
  }

  func tearDown() {
    APICredentials.shared = nil
  }
}
```

Many testing systems use this pattern, including XCTest. However, this approach
encourages the use of global mutable state such as the `APICredentials.shared`
variable, and this limits the testing library's ability to parallelize test
execution, which is
[another part of the Swift Testing vision](https://github.com/swiftlang/swift-evolution/blob/main/visions/swift-testing.md#parallelization-and-concurrency).

The use of nonisolated static variables is generally discouraged now, and in
Swift 6 the above `APICredentials.shared` property produces an error. One way
to resolve that is to change it to a `@TaskLocal` variable, as this would be
concurrency-safe and still allow tests accessing this state to run in parallel:

```swift
extension APICredentials {
  @TaskLocal static var current: Self?
}
```

Binding task local values requires using the scoped access
[`TaskLocal.withValue()`](https://developer.apple.com/documentation/swift/tasklocal/withvalue(_:operation:isolation:file:line:))
API though, and that would not be possible if `Trait` exposed separate methods
like `setUp()` and `tearDown()`.

For these reasons, I believe it's important to expose this trait capability
using a single, scoped access-style API which accepts a closure. A simplified
version of that idea might look like this:

```swift
public protocol Trait: Sendable {
  // ...

  // Simplified example, not the actual proposal
  func executeTest(_ body: @Sendable () async throws -> Void) async throws
}

extension MockAPICredentialsTrait {
  func executeTest(_ body: @Sendable () async throws -> Void) async throws {
    let mockCredentials = APICredentials(apiKey: "...")
    try await APICredentials.$current.withValue(mockCredentials) {
      try await body()
    }
  }
}
```

### Avoiding unnecessarily lengthy backtraces

A scoped access-style API has some potential downsides. To apply this approach
to a test function, the scoped call of a trait must wrap the invocation of that
test function, and every _other_ trait applied to that same test which offers
custom behavior _also_ must wrap the other traits' calls in a nesting fashion.
To visualize this, imagine a test function with multiple traits:

```swift
@Test(.traitA, .traitB, .traitC)
func exampleTest() {
  // ...
}
```

If all three of those traits customize test execution behavior, then each of
them needs to wrap the call to the next one, and the last trait needs to wrap
the invocation of the test, illustrated by the following:

```
TraitA.executeTest {
  TraitB.executeTest {
    TraitC.executeTest {
      exampleTest()
    }
  }
}
```

Tests may have an arbitrary number of traits applied to them, including those
inherited from containing suite types. A naïve implementation in which _every_
trait is given the opportunity to customize test behavior by calling its scoped
access API might cause unnecessarily lengthy backtraces that make debugging the
body of tests more difficult. Or worse: if the number of traits is great enough,
it could cause a stack overflow.

In practice, most traits probably will _not_ need to customize test behavior, so
to mitigate these downsides it's important that there be some way to distinguish
traits which customize test behavior. That way, the testing library can limit
these scoped access calls to only the traits which require it.

## Detailed design

I propose the following new APIs:

- A new protocol `CustomTestExecuting` with a single required `execute(...)`
  method. This will be called to run a test, and allows the conforming type to
  perform custom logic before or after.
- A new property `customTestExecutor` on the `Trait` protocol whose type is an
  `Optional` value of a type conforming to `CustomTestExecuting`. A `nil` value
  from this property will skip calling the `execute(...)` method.
- A default implementation of `Trait.customTestExecutor` whose value is `nil`.
- A conditional implementation of `Trait.customTestExecutor` whose value is
  `self` in the common case where the trait type conforms to
  `CustomTestExecuting` itself.

Since the `customTestExecutor` property is optional and `nil` by default, the
testing library cannot invoke the `execute(...)` method unless a trait
customizes test behavior. This avoids the "unnecessarily lengthy backtraces"
problem above.

Below are the proposed interfaces:

```swift
/// A protocol that allows customizing the execution of a test function (and
/// each of its cases) or a test suite by performing custom code before or after
/// it runs.
public protocol CustomTestExecuting: Sendable {
  /// Execute a function for the specified test and/or test case.
  ///
  /// - Parameters:
  ///   - function: The function to perform. If `test` represents a test suite,
  ///     this function encapsulates running all the tests in that suite. If
  ///     `test` represents a test function, this function is the body of that
  ///     test function (including all cases if it is parameterized.)
  ///   - test: The test under which `function` is being performed.
  ///   - testCase: The test case, if any, under which `function` is being
  ///     performed. This is `nil` when invoked on a suite.
  ///
  /// - Throws: Whatever is thrown by `function`, or an error preventing
  ///   execution from running correctly.
  ///
  /// This function is called for each ``Trait`` on a test suite or test
  /// function which has a non-`nil` value for ``Trait/customTestExecutor-1dwpt``.
  /// It allows additional work to be performed before or after the test runs.
  ///
  /// This function is invoked once for the test its associated trait is applied
  /// to, and then once for each test case in that test, if applicable. If a
  /// test is skipped, this function is not invoked for that test or its cases.
  ///
  /// Issues recorded by this function are associated with `test`.
  func execute(_ function: @Sendable () async throws -> Void, for test: Test, testCase: Test.Case?) async throws
}

public protocol Trait: Sendable {
  // ...

  /// The type of the custom test executor for this trait.
  ///
  /// The default type is `Never`.
  associatedtype CustomTestExecutor: CustomTestExecuting = Never

  /// The custom test executor for this trait, if any.
  ///
  /// If this trait's type conforms to ``CustomTestExecuting``, the default
  /// value of this property is `self` and this trait will be used to customize
  /// test execution. This is the most straightforward way to implement a trait
  /// which customizes the execution of tests.
  ///
  /// However, if the value of this property is an instance of another type
  /// conforming to ``CustomTestExecuting``, that instance will be used to
  /// perform custom test execution instead.  Otherwise, the default value of
  /// this property is `nil` (with the default type `Never?`), meaning that
  /// custom test execution will not be performed for tests this trait is
  /// applied to.
  var customTestExecutor: CustomTestExecutor? { get }
}

extension Trait {
  // ...

  // The default implementation, which returns `nil`.
  public var customTestExecutor: CustomTestExecutor? { get }
}

extension Trait where CustomTestExecutor == Self {
  // Returns `self`.
  public var customTestExecutor: CustomTestExecutor? { get }
}

extension Never: CustomTestExecuting {
  public func execute(_ function: @Sendable () async throws -> Void, for test: Test, testCase: Test.Case?) async throws
}
```

Here is a complete example of the usage scenario described earlier, showcasing
the proposed APIs:

```swift
@Test(.mockAPICredentials)
func example() {
  // ...validate API usage, referencing `APICredentials.current`...
}

struct MockAPICredentialsTrait: TestTrait, CustomTestExecuting {
  func execute(_ function: @Sendable () async throws -> Void, for test: Test, testCase: Test.Case?) async throws {
    let mockCredentials = APICredentials(apiKey: "...")
    try await APICredentials.$current.withValue(mockCredentials) {
      try await function()
    }
  }
}

extension Trait where Self == MockAPICredentialsTrait {
  static var mockAPICredentials: Self {
    Self()
  }
}
```

## Source compatibility

The proposed APIs are purely additive.

## Integration with supporting tools

Although some built-in traits are relevant to supporting tools (such as
SourceKit-LSP statically discovering `.tags` traits), custom test behaviors are
only relevant within the test executable process while tests are running. We
don't anticipate any particular need for this feature to integrate with
supporting tools.

## Future directions

Some test authors have expressed interest in allowing custom traits to access
the instance of a suite type for `@Test` instance methods, so the trait could
inspect or mutate the instance. Currently, only instance-level members of a
suite type (including `init`, `deinit`, and the test function itself) can access
`self`, so this would grant traits applied to an instance test method access to
the instance as well. This is certainly interesting, but poses several technical
challenges that puts it out of scope of this proposal.

## Alternatives considered

### Separate set up & tear down methods on `Trait`

This idea was discussed in [Supporting scoped access](#supporting-scoped-access)
above, and as mentioned there, the primary problem with this approach is that it
cannot be used with scoped access-style APIs, including (importantly)
`TaskLocal.withValue()`. For that reason, it prevents using that common Swift
concurrency technique and reduces the potential for test parallelization.

### Add `execute(...)` directly to the `Trait` protocol

The proposed `execute(...)` method could be added as a requirement of the
`Trait` protocol instead of being part of a separate `CustomTestExecuting`
protocol, and it could have a default implementation which directly invokes the
passed-in closure. But this approach would suffer from the lengthy backtrace
problem described above.

### Extend the `Trait` protocol

The original, experimental implementation of this feature included a protocol
named`CustomExecutionTrait` which extended `Trait` and had roughly the same
method requirement as the `CustomTestExecuting` protocol proposed above. This
design worked, provided scoped access, and avoided the lengthy backtrace problem.

After evaluating the design and usage of this SPI though, it seemed unfortunate
to structure it as a sub-protocol of `Trait` because it means that the full
capabilities of the trait system are spread across multiple protocols. In the
proposed design, the ability to provide a custom test executor value is exposed
via the main `Trait` protocol, and it relies on an associated type to
conditionally opt-in to custom test behavior. In other words, the proposed
design expresses custom test behavior as just a _capability_ that a trait may
have, rather than a distinct sub-type of trait.

Also, the implementation of this approach within the testing library was not
ideal as it required a conditional `trait as? CustomExecutionTrait` downcast at
runtime, in contrast to the simpler and more performant Optional property of the
proposed API.

## Acknowledgments

Thanks to [Dennis Weissmann](https://github.com/dennisweissmann) for originally
implementing this as SPI, and for helping promote its usefulness.

Thanks to [Jonathan Grynspan](https://github.com/grynspan) for exploring ideas
to refine the API, and considering alternatives to avoid unnecessarily long
backtraces.
