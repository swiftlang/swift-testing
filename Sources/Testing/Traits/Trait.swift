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

extension SuiteTrait {
  public var isRecursive: Bool {
    false
  }
}

/// A protocol extending ``Trait`` that offers an additional customization point
/// for trait authors to execute code before and after each test function (if
/// added to the traits of a test function), or before and after each test suite
/// (if added to the traits of a test suite).
@_spi(Experimental)
public protocol CustomExecutionTrait: Trait {

  /// Execute a function with the effects of this trait applied.
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
  /// - Throws: Whatever is thrown by `function`, or an error preventing the
  ///   trait from running correctly.
  ///
  /// This function is called for each ``CustomExecutionTrait`` on a test suite
  /// or test function and allows additional work to be performed before and
  /// after the test runs.
  ///
  /// This function is invoked once for the test it is applied to, and then once
  /// for each test case in that test, if applicable.
  ///
  /// Issues recorded by this function are recorded against `test`.
  ///
  /// - Note: If a test function or test suite is skipped, this function does
  ///   not get invoked by the runner.
  func execute(_ function: @Sendable () async throws -> Void, for test: Test, testCase: Test.Case?) async throws
}
