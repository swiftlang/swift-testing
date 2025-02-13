//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that defines whether the testing library runs this test serially
/// or in parallel.
///
/// When you add this trait to a parameterized test function, that test runs its
/// cases serially instead of in parallel. This trait has no effect when you
/// apply it to a non-parameterized test function.
///
/// When you add this trait to a test suite, that suite runs its
/// contained test functions (including their cases, when parameterized) and
/// sub-suites serially instead of in parallel. If the sub-suites have children,
/// they also run serially.
///
/// This trait does not affect the execution of a test relative to its peers or
/// to unrelated tests. This trait has no effect if you disable test
/// parallelization globally (for example, by passing `--no-parallel` to the
/// `swift test` command.)
///
/// To add this trait to a test, use ``Trait/serialized``.
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
