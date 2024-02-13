//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A protocol describing traits that can be added to a test function or to a
/// test suite and that make use of SPI symbols in the testing library.
///
/// This protocol refines ``Trait`` in various ways that require the use of SPI.
/// Ideally, such requirements will be promoted to API when their design
/// stabilizes.
@_spi(ExperimentalTestRunning)
public protocol SPIAwareTrait: Trait {
  /// Prepare to run the test to which this trait was added.
  ///
  /// - Parameters:
  ///   - test: The test to which this trait was added.
  ///   - action: The test plan action to use with `test`. The implementation
  ///     may modify this value.
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
  /// For types that conform to this protocol, ``Runner/Plan`` calls this method
  /// instead of ``Trait/prepare(for:)``.
  func prepare(for test: Test, action: inout Runner.Plan.Action) async throws
}
