//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A protocol describing traits that can be added to a test function or to a
/// test suite.
///
/// The testing library defines a number of traits that can be added to test
/// functions and to test suites. Define your own traits by
/// creating types that conform to ``TestTrait`` or ``SuiteTrait``:
///
/// - term ``TestTrait``: Conform to this type in traits that you add to test
///   functions.
/// - term ``SuiteTrait``: Conform to this type in traits that you add to test
///   suites.
///
/// You can add a trait that conforms to both ``TestTrait`` and ``SuiteTrait``
/// to test functions and test suites.
public protocol Trait: Sendable {
  /// Prepare to run the test that has this trait.
  ///
  /// - Parameters:
  ///   - test: The test that has this trait.
  ///
  /// - Throws: Any error that prevents the test from running. If an error
  ///   is thrown from this method, the test is skipped and the error is
  ///   recorded as an ``Issue``.
  ///
  /// The testing library calls this method after it discovers all tests and
  /// their traits, and before it begins to run any tests.
  /// Use this method to prepare necessary internal state, or to determine
  /// whether the test should run.
  ///
  /// The default implementation of this method does nothing.
  func prepare(for test: Test) async throws

  /// The user-provided comments for this trait.
  ///
  /// The default value of this property is an empty array.
  var comments: [Comment] { get }

  /// The type of the test scope provider for this trait.
  ///
  /// The default type is `Never`, which can't be instantiated. The
  /// ``scopeProvider(for:testCase:)-cjmg`` method for any trait with
  /// `Never` as its test scope provider type must return `nil`, meaning that
  /// the trait doesn't provide a custom scope for tests it's applied to.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.1)
  ///   @Available(Xcode, introduced: 16.3)
  /// }
  associatedtype TestScopeProvider: TestScoping = Never

  /// Get this trait's scope provider for the specified test and optional test
  /// case.
  ///
  /// - Parameters:
  ///   - test: The test for which a scope provider is being requested.
  ///   - testCase: The test case for which a scope provider is being requested,
  ///     if any. When `test` represents a suite, the value of this argument is
  ///     `nil`.
  ///
  /// - Returns: A value conforming to ``Trait/TestScopeProvider`` which you
  ///   use to provide custom scoping for `test` or `testCase`. Returns `nil` if
  ///   the trait doesn't provide any custom scope for the test or test case.
  ///
  /// If this trait's type conforms to ``TestScoping``, the default value
  /// returned by this method depends on the values of`test` and `testCase`:
  ///
  /// - If `test` represents a suite, this trait must conform to ``SuiteTrait``.
  ///   If the value of this suite trait's ``SuiteTrait/isRecursive`` property
  ///   is `true`, then this method returns `nil`, and the suite trait
  ///   provides its custom scope once for each test function the test suite
  ///   contains. If the value of ``SuiteTrait/isRecursive`` is `false`, this
  ///   method returns `self`, and the suite trait provides its custom scope
  ///   once for the entire test suite.
  /// - If `test` represents a test function, this trait also conforms to
  ///   ``TestTrait``. If `testCase` is `nil`, this method returns `nil`;
  ///   otherwise, it returns `self`. This means that by default, a trait which
  ///   is applied to or inherited by a test function provides its custom scope
  ///   once for each of that function's cases.
  ///
  /// A trait may override this method to further customize the
  /// default behaviors above. For example, if a trait needs to provide custom
  /// test scope both once per-suite and once per-test function in that suite,
  /// it implements the method to return a non-`nil` scope provider under
  /// those conditions.
  ///
  /// A trait may also implement this method and return `nil` if it determines
  /// that it does not need to provide a custom scope for a particular test at
  /// runtime, even if the test has the trait applied. This can improve
  /// performance and make diagnostics clearer by avoiding an unnecessary call
  /// to ``TestScoping/provideScope(for:testCase:performing:)``.
  ///
  /// If this trait's type does not conform to ``TestScoping`` and its
  /// associated ``Trait/TestScopeProvider`` type is the default `Never`, then
  /// this method returns `nil` by default. This means that instances of this
  /// trait don't provide a custom scope for tests to which they're applied.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.1)
  ///   @Available(Xcode, introduced: 16.3)
  /// }
  func scopeProvider(for test: Test, testCase: Test.Case?) -> TestScopeProvider?
}

/// A protocol that tells the test runner to run custom code before or after it
/// runs a test suite or test function.
///
/// Provide custom scope for tests by implementing the
/// ``Trait/scopeProvider(for:testCase:)-cjmg`` method, returning a type that
/// conforms to this protocol. Create a custom scope to consolidate common
/// set-up and tear-down logic for tests which have similar needs, which allows
/// each test function to focus on the unique aspects of its test.
///
/// @Metadata {
///   @Available(Swift, introduced: 6.1)
///   @Available(Xcode, introduced: 16.3)
/// }
public protocol TestScoping: Sendable {
  /// Provide custom execution scope for a function call which is related to the
  /// specified test or test case.
  ///
  /// - Parameters:
  ///   - test: The test which `function` encapsulates.
  ///   - testCase: The test case, if any, which `function` encapsulates.
  ///     When invoked on a suite, the value of this argument is `nil`.
  ///   - function: The function to perform. If `test` represents a test suite,
  ///     this function encapsulates running all the tests in that suite. If
  ///     `test` represents a test function, this function is the body of that
  ///     test function (including all cases if the test function is
  ///     parameterized.)
  ///
  /// - Throws: Any error that `function` throws, or an error that prevents this
  ///   type from providing a custom scope correctly. The testing library
  ///   records an error thrown from this method as an issue associated with
  ///   `test`. If an error is thrown before this method calls `function`, the
  ///   corresponding test doesn't run.
  ///
  /// When the testing library prepares to run a test, it starts by finding
  /// all traits applied to that test, including those inherited from containing
  /// suites. It begins with inherited suite traits, sorting them
  /// outermost-to-innermost, and if the test is a function, it then adds all
  /// traits applied directly to that functions in the order they were applied
  /// (left-to-right). It then asks each trait for its scope provider (if any)
  /// by calling ``Trait/scopeProvider(for:testCase:)-cjmg``. Finally, it calls
  /// this method on all non-`nil` scope providers, giving each an opportunity
  /// to perform arbitrary work before or after invoking `function`.
  ///
  /// This method should either invoke `function` once before returning,
  /// or throw an error if it's unable to provide a custom scope.
  ///
  /// Issues recorded by this method are associated with `test`.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.1)
  ///   @Available(Xcode, introduced: 16.3)
  /// }
  func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws
}

extension Trait where Self: TestScoping {
  /// Get this trait's scope provider for the specified test or test case.
  ///
  /// - Parameters:
  ///   - test: The test for which the testing library requests a
  ///     scope provider.
  ///   - testCase: The test case for which the testing library requests a scope
  ///     provider, if any. When `test` represents a suite, the value of this argument is
  ///     `nil`.
  ///
  /// The testing library uses this implementation of
  /// ``Trait/scopeProvider(for:testCase:)-cjmg`` when the trait type conforms
  /// to ``TestScoping``.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.1)
  ///   @Available(Xcode, introduced: 16.3)
  /// }
  public func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
    testCase == nil ? nil : self
  }
}

extension SuiteTrait where Self: TestScoping {
  /// Get this trait's scope provider for the specified test and optional test
  /// case.
  ///
  /// - Parameters:
  ///   - test: The test for which the testing library requests a scope
  ///     provider.
  ///   - testCase: The test case for which the testing library requests a scope
  ///     provider, if any. When `test` represents a suite, the value of this
  ///     argument is `nil`.
  ///
  /// The testing library uses this implementation of
  /// ``Trait/scopeProvider(for:testCase:)-cjmg`` when the trait type conforms
  /// to both ``SuiteTrait`` and ``TestScoping``.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.1)
  ///   @Available(Xcode, introduced: 16.3)
  /// }
  public func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
    if test.isSuite {
      isRecursive ? nil : self
    } else {
      testCase == nil ? nil : self
    }
  }
}

extension Never: TestScoping {
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.1)
  ///   @Available(Xcode, introduced: 16.3)
  /// }
  public func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {}
}

/// A protocol describing a trait that you can add to a test function.
///
/// The testing library defines a number of traits that you can add to test
/// functions. You can also define your own traits by creating types
/// that conform to this protocol, or to the ``SuiteTrait`` protocol.
public protocol TestTrait: Trait {}

/// A protocol describing a trait that you can add to a test suite.
///
/// The testing library defines a number of traits that you can add to test
/// suites. You can also define your own traits by creating types that
/// conform to this protocol, or to the ``TestTrait`` protocol.
public protocol SuiteTrait: Trait {
  /// Whether this instance should be applied recursively to child test suites
  /// and test functions.
  ///
  /// If the value is `true`, then the testing library applies this trait
  /// recursively to child test suites and test functions. Otherwise, it only
  /// applies the trait to the test suite to which you added the trait.
  ///
  /// By default, traits are not recursively applied to children.
  var isRecursive: Bool { get }
}

extension Trait {
  public func prepare(for test: Test) async throws {}

  public var comments: [Comment] {
    []
  }
}

extension Trait where TestScopeProvider == Never {
  /// Get this trait's scope provider for the specified test or test case.
  ///
  /// - Parameters:
  ///   - test: The test for which the testing library requests a
  ///     scope provider.
  ///   - testCase: The test case for which the testing library requests a scope
  ///     provider, if any. When `test` represents a suite, the value of this argument is
  ///     `nil`.
  ///
  /// The testing library uses this implementation of
  /// ``Trait/scopeProvider(for:testCase:)-cjmg`` when the trait type's
  /// associated ``Trait/TestScopeProvider`` type is `Never`.
  ///
  /// @Metadata {
  ///   @Available(Swift, introduced: 6.1)
  ///   @Available(Xcode, introduced: 16.3)
  /// }
  public func scopeProvider(for test: Test, testCase: Test.Case?) -> Never? {
    nil
  }
}

extension SuiteTrait {
  public var isRecursive: Bool {
    false
  }
}

extension Test {
  /// Whether or not this test contains the specified trait.
  ///
  /// - Parameters:
  ///   - trait: The trait to search for. Must conform to `Equatable`.
  ///
  /// - Returns: Whether or not this test contains `trait`.
  func containsTrait<T>(_ trait: T) -> Bool where T: Trait & Equatable {
    traits.contains { ($0 as? T) == trait }
  }
}
