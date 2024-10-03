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

  /// The type of the test executor for this trait.
  ///
  /// The default type is `Never`, which cannot be instantiated. This means the
  /// value of the ``testExecutor-714gp`` property for all traits with
  /// the default custom executor type is `nil`, meaning such traits will not
  /// perform any custom execution for the tests they're applied to.
  associatedtype TestExecutor: TestExecuting = Never

  /// The test executor for this trait, if any.
  ///
  /// If this trait's type conforms to ``TestExecuting``, the default value of
  /// this property is `self` and this trait will be used to customize test
  /// execution. This is the most straightforward way to implement a trait which
  /// customizes the execution of tests.
  ///
  /// If the value of this property is an instance of a different type
  /// conforming to ``TestExecuting``, that instance will be used to perform
  /// test execution instead.
  ///
  /// The default value of this property is `nil` (with the default type
  /// `Never?`), meaning that instances of this type will not perform any custom
  /// test execution for tests they are applied to.
  var testExecutor: TestExecutor? { get }
}

/// A protocol that allows customizing the execution of a test function (and
/// each of its cases) or a test suite by performing custom code before or after
/// it runs.
///
/// Types conforming to this protocol may be used in conjunction with a
/// ``Trait``-conforming type by implementing the
/// ``Trait/testExecutor-714gp`` property, allowing custom traits to
/// customize the execution of tests. Consolidating common set-up and tear-down
/// logic for tests which have similar needs allows each test function to be
/// more succinct with less repetitive boilerplate so it can focus on what makes
/// it unique.
public protocol TestExecuting: Sendable {
  /// Execute a function for the specified test and/or test case.
  ///
  /// - Parameters:
  ///   - function: The function to perform. If `test` represents a test suite,
  ///     this function encapsulates running all the tests in that suite. If
  ///     `test` represents a test function, this function is the body of that
  ///     test function (including all cases if it is parameterized.)
  ///   - test: The test under which `function` is being performed.
  ///   - testCase: The test case, if any, under which `function` is being
  ///     performed. When invoked on a suite, the value of this argument is
  ///     `nil`.
  ///
  /// - Throws: Whatever is thrown by `function`, or an error preventing
  ///   execution from running correctly. An error thrown from this method is
  ///   recorded as an issue associated with `test`. If an error is thrown
  ///   before `function` is called, the corresponding test will not run.
  ///
  /// When the testing library is preparing to run a test, it finds all traits
  /// applied to that test (including those inherited from containing suites)
  /// and asks each for the value of its
  /// ``Trait/testExecutor-714gp`` property. It then calls this method
  /// on all non-`nil` instances, giving each an opportunity to perform
  /// arbitrary work before or after invoking `function`.
  ///
  /// This method should either invoke `function` once before returning or throw
  /// an error if it is unable to perform its custom logic successfully.
  ///
  /// This method is invoked once for the test its associated trait is applied
  /// to, and then once for each test case in that test, if applicable. If a
  /// test is skipped, this method is not invoked for that test or its cases.
  ///
  /// Issues recorded by this method are associated with `test`.
  func execute(_ function: @Sendable () async throws -> Void, for test: Test, testCase: Test.Case?) async throws
}

extension Trait where Self: TestExecuting {
  public var testExecutor: Self? {
    self
  }
}

extension Never: TestExecuting {
  public func execute(_ function: @Sendable () async throws -> Void, for test: Test, testCase: Test.Case?) async throws {}
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
}

extension Trait where TestExecutor == Never {
  public var testExecutor: TestExecutor? {
    nil
  }
}

extension SuiteTrait {
  public var isRecursive: Bool {
    false
  }
}
