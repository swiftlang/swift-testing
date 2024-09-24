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
/// functions and to test suites. Developers can define their own traits by
/// creating types that conform to ``TestTrait`` and/or ``SuiteTrait``.
///
/// When creating a custom trait type, the type should conform to ``TestTrait``
/// if it can be added to test functions, ``SuiteTrait`` if it can be added to
/// test suites, and both ``TestTrait`` and ``SuiteTrait`` if it can be added to
/// both test functions _and_ test suites.
public protocol Trait: Sendable {
  /// Prepare to run the test to which this trait was added.
  ///
  /// - Parameters:
  ///   - test: The test to which this trait was added.
  ///
  /// - Throws: Any error that would prevent the test from running. If an error
  ///   is thrown from this method, the test will be skipped and the error will
  ///   be recorded as an ``Issue``.
  ///
  /// This method is called after all tests and their traits have been
  /// discovered by the testing library, but before any test has begun running.
  /// It may be used to prepare necessary internal state, or to influence
  /// whether the test should run.
  ///
  /// The default implementation of this method does nothing.
  func prepare(for test: Test) async throws

  /// The user-provided comments for this trait, if any.
  ///
  /// By default, the value of this property is an empty array.
  var comments: [Comment] { get }

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

extension Trait where CustomTestExecutor == Self {
  public var customTestExecutor: CustomTestExecutor? {
    self
  }
}

extension Never: CustomTestExecuting {
  public func execute(_ function: @Sendable () async throws -> Void, for test: Test, testCase: Test.Case?) async throws {
    fatalError("Unreachable codepath: Never cannot be instantiated.")
  }
}

/// A protocol describing traits that can be added to a test function.
///
/// The testing library defines a number of traits that can be added to test
/// functions. Developers can also define their own traits by creating types
/// that conform to this protocol and/or to the ``SuiteTrait`` protocol.
public protocol TestTrait: Trait {}

/// A protocol describing traits that can be added to a test suite.
///
/// The testing library defines a number of traits that can be added to test
/// suites. Developers can also define their own traits by creating types that
/// conform to this protocol and/or to the ``TestTrait`` protocol.
public protocol SuiteTrait: Trait {
  /// Whether this instance should be applied recursively to child test suites
  /// and test functions or should only be applied to the test suite to which it
  /// was directly added.
  ///
  /// By default, traits are not recursively applied to children.
  var isRecursive: Bool { get }
}

extension Trait {
  public func prepare(for test: Test) async throws {}

  public var comments: [Comment] {
    []
  }

  public var customTestExecutor: CustomTestExecutor? {
    nil
  }
}

extension SuiteTrait {
  public var isRecursive: Bool {
    false
  }
}
