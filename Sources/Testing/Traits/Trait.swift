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

  /// Make a copy of this trait that stores its source code representation.
  ///
  /// - Parameters:
  ///   - sourceCode: The source code representation of the entire trait.
  ///   - arguments: Source code representations of each argument to the trait,
  ///     if any.
  ///
  /// - Returns: A modified copy of `self`.
  ///
  /// The default implementation of this method does nothing and returns `self`
  /// unmodified.
  func addingSourceCode(
    _ sourceCode: @autoclosure () -> SourceCode,
    arguments: @autoclosure () -> [(label: String?, sourceCode: SourceCode)]
  ) -> Self
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

  public func addingSourceCode(
    _ sourceCode: @autoclosure () -> SourceCode,
    arguments: @autoclosure () -> [(label: String?, sourceCode: SourceCode)]
  ) -> Self {
    self
  }
}

extension SuiteTrait {
  public var isRecursive: Bool {
    false
  }
}
