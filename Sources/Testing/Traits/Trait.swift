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
  /// The default type is `Never`, which cannot be instantiated. The
  /// ``executor(for:testCase:)-26qgm`` method for any trait with this default
  /// test executor type must return `nil`, meaning that trait will not perform
  /// any custom behavior for the tests it's applied to.
  associatedtype TestExecutor: TestExecuting = Never

  /// Get this trait's executor for the specified test and/or test case, if any.
  ///
  /// - Parameters:
  ///   - test: The test for which an executor is being requested.
  ///   - testCase: The test case for which an executor is being requested, if
  ///     any. When `test` represents a suite, the value of this argument is
  ///     `nil`.
  ///
  /// - Returns: An value of ``Trait/TestExecutor`` which should be used to
  ///   customize the behavior of `test` and/or `testCase`, or `nil` if custom
  ///   behavior should not be performed.
  ///
  /// If this trait's type conforms to ``TestExecuting``, the default value
  /// returned by this method depends on `test` and/or `testCase`:
  ///
  /// - If `test` represents a suite, this trait must conform to ``SuiteTrait``.
  ///   If the value of this suite trait's ``SuiteTrait/isRecursive`` property
  ///   is `true`, then this method returns `nil`; otherwise, it returns `self`.
  ///   This means that by default, a suite trait will _either_ perform its
  ///   custom behavior once for the entire suite, or once per-test function it
  ///   contains.
  /// - Otherwise `test` represents a test function. If `testCase` is `nil`,
  ///   this method returns `nil`; otherwise, it returns `self`. This means that
  ///   by default, a trait which is applied to or inherited by a test function
  ///   will perform its custom behavior once for each of that function's cases.
  ///
  /// A trait may explicitly implement this method to further customize the
  /// default behaviors above. For example, if a trait should perform custom
  /// test behavior both once per-suite and once per-test function in that suite,
  /// it may implement the method and return a non-`nil` executor under those
  /// conditions.
  ///
  /// A trait may also implement this method and return `nil` if it determines
  /// that it does not need to perform any custom behavior for a particular test
  /// at runtime, even if the test has the trait applied. This can improve
  /// performance and make diagnostics clearer by avoiding an unnecessary call
  /// to ``TestExecuting/execute(_:for:testCase:)``.
  ///
  /// If this trait's type does not conform to ``TestExecuting`` and its
  /// associated ``Trait/TestExecutor`` type is the default `Never`, then this
  /// method returns `nil` by default. This means that instances of this type
  /// will not perform any custom test execution for tests they are applied to.
  func executor(for test: Test, testCase: Test.Case?) -> TestExecutor?
}

/// A protocol that allows customizing the execution of a test function (and
/// each of its cases) or a test suite by performing custom code before or after
/// it runs.
///
/// Types conforming to this protocol may be used in conjunction with a
/// ``Trait``-conforming type by implementing the
/// ``Trait/executor(for:testCase:)-26qgm`` method, allowing custom traits to
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
  /// and asks each for its test executor (if any) by calling
  /// ``Trait/executor(for:testCase:)-26qgm``. It then calls this method
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
  public func executor(for test: Test, testCase: Test.Case?) -> Self? {
    testCase == nil ? nil : self
  }
}

extension SuiteTrait where Self: TestExecuting {
  public func executor(for test: Test, testCase: Test.Case?) -> Self? {
    if test.isSuite {
      isRecursive ? nil : self
    } else {
      testCase == nil ? nil : self
    }
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
  public func executor(for test: Test, testCase: Test.Case?) -> TestExecutor? {
    nil
  }
}

extension SuiteTrait {
  public var isRecursive: Bool {
    false
  }
}
