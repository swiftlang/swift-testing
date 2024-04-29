//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that affects whether or not a test or suite is parallelized.
///
/// When added to a parameterized test function, this trait causes that test to
/// run its cases serially instead of in parallel. When applied to a
/// non-parameterized test function, this trait has no effect. When applied to a
/// test suite, this trait causes that suite to run its contained test functions
/// and sub-suites serially instead of in parallel.
///
/// This trait is recursively applied: if it is applied to a suite, any
/// parameterized tests or test suites contained in that suite are also
/// serialized (as are any tests contained in those suites, and so on.)
///
/// This trait does not affect the execution of a test relative to its peers or
/// to unrelated tests. This trait has no effect if test parallelization is
/// globally disabled (by, for example, passing `--no-parallel` to the
/// `swift test` command.)
///
/// To add this trait to a test, use ``Trait/serialized``.
@_spi(Experimental)
public struct ParallelizationTrait: TestTrait, SuiteTrait {
  public var isRecursive: Bool {
    true
  }
}

// MARK: - SPIAwareTrait

@_spi(ForToolsIntegrationOnly)
extension ParallelizationTrait: SPIAwareTrait {
  public func prepare(for test: Test, action: inout Runner.Plan.Action) async throws {
    if case var .run(options) = action {
      options.isParallelizationEnabled = false
      action = .run(options: options)
    }
  }
}

// MARK: -

@_spi(Experimental)
extension Trait where Self == ParallelizationTrait {
  /// A trait that serializes the test to which it is applied.
  ///
  /// ## See Also
  ///
  /// - ``ParallelizationTrait``
  public static var serialized: Self {
    Self()
  }
}
