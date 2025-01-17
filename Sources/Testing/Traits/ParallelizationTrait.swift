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
/// run its cases serially instead of in parallel. When added to a
/// non-parameterized test function, this trait has no effect.
///
/// When added to a test suite, this trait causes that suite to run its
/// contained test functions (including their cases, when parameterized) and
/// sub-suites serially instead of in parallel. Any children of sub-suites are
/// also run serially.
///
/// This trait does not affect the execution of a test relative to its peers or
/// to unrelated tests. This trait has no effect if test parallelization is
/// globally disabled (by, for example, passing `--no-parallel` to the
/// `swift test` command.)
///
/// To add this trait to a test, use ``Trait/serialized`` or
/// ``Trait/serialized(_:)``.
public struct ParallelizationTrait: TestTrait, SuiteTrait {
  /// Scopes in which suites and test functions can be serialized using the
  /// ``serialized(_:)`` trait.
  @_spi(Experimental)
  public enum Scope: Sendable, Equatable, Hashable, Comparable {
    /// Parallelization is applied locally.
    ///
    /// TODO: More blurb.
    case locally

    /// Parallelization is applied across all suites and test functions in the
    /// given group.
    ///
    /// TODO: More blurb.
    case withinGroup(_ groupName: String)

    /// Parallelization is applied globally.
    ///
    /// TODO: More blurb.
    case globally
  }

  var scope: Scope

  public var isRecursive: Bool {
    true
  }
}

// MARK: - TestScoping

extension ParallelizationTrait: TestScoping {
  /// Storage for ``scheduler(for:)``.
  private static let _workGroups = Locked<[ParallelizationTrait.Scope: WorkGroup]>()

  static func workGroup(for scope: Scope) -> WorkGroup {
    _workGroups.withLock { workGroups in
      var result = workGroups[scope]
      if result == nil {
        result = WorkGroup()
        workGroups[scope] = result
      }
      return result!
    }
  }

  public func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
    try await Self.workGroup(for: scope).run(isBarrier: true) {
      try await function()
    }
  }
}

// MARK: -

extension Trait where Self == ParallelizationTrait {
  /// A trait that serializes the test to which it is applied.
  ///
  /// This value is equivalent to ``serialized(_:)`` with the argument
  /// ``ParallelizationTrait/Scope/locally``.
  ///
  /// ## See Also
  ///
  /// - ``ParallelizationTrait``
  public static var serialized: Self {
    Self(scope: .locally)
  }

  /// A trait that serializes the test to which it is applied.
  ///
  /// - Parameters:
  ///   - scope: The scope in which parallelization is enforced.
  ///
  /// ## See Also
  ///
  /// - ``ParallelizationTrait``
  @_spi(Experimental)
  public static func serialized(_ scope: ParallelizationTrait.Scope) -> Self {
    Self(scope: scope)
  }
}

// MARK: -

extension Test {
  /// Whether or not this test has been serialized.
  var isSerialized: Bool {
    traits.lazy.contains { $0 is ParallelizationTrait }
  }
}
