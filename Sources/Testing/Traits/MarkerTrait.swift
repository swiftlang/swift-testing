//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type which indicates a boolean value when used as a test trait.
///
/// Any attribute of a test which can be represented as a boolean value may use
/// an instance of this type to indicate having that attribute by adding it to
/// that test's traits.
///
/// Instances of this type are considered equal if they have an identical
/// private reference to a value of reference type, so each unique marker must
/// be a shared instance.
///
/// This type is not part of the public interface of the testing library.
struct MarkerTrait: TestTrait, SuiteTrait {
  /// A stored value of a reference type used solely for equality checking, so
  /// that two marker instances may be considered equal only if they have
  /// identical values for this property.
  ///
  /// @Comment {
  ///   - Bug: We cannot use a custom class for this purpose because in some
  ///     scenarios, more than one instance of the testing library may be loaded
  ///     in to a test runner process and on certain platforms this can cause
  ///     runtime warnings. ([148912491](rdar://148912491))
  /// }
  nonisolated(unsafe) private let _identity: AnyObject = ManagedBuffer<Void, Void>.create(minimumCapacity: 0) { _ in () }

  let isRecursive: Bool
}

extension MarkerTrait: Equatable {
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs._identity === rhs._identity
  }
}

#if DEBUG
// MARK: - Hidden tests

/// Storage for the ``Trait/hidden`` property.
private let _hiddenMarker = MarkerTrait(isRecursive: true)

extension Trait where Self == MarkerTrait {
  /// A trait that indicates that a test should be hidden from automatic
  /// discovery and only run if explicitly requested.
  ///
  /// This is different from disabled or skipped, and is primarily meant to be
  /// used on tests defined in this project's own test suite, so that example
  /// tests can be defined using the `@Test` attribute but not run by default
  /// except by the specific unit test(s) which have requested to run them.
  ///
  /// When this trait is applied to a suite, it is recursively inherited by all
  /// child suites and tests.
  static var hidden: Self {
    _hiddenMarker
  }
}

extension Test {
  /// Whether this test is hidden, whether directly or via a trait inherited
  /// from a parent test.
  ///
  /// ## See Also
  ///
  /// - ``Trait/hidden``
  var isHidden: Bool {
    containsTrait(.hidden)
  }
}

// MARK: - Synthesized tests

/// Storage for the ``Trait/synthesized`` property.
private let _synthesizedMarker = MarkerTrait(isRecursive: false)

extension Trait where Self == MarkerTrait {
  /// A trait that indicates a test was synthesized at runtime.
  ///
  /// During test planning, suites that are not explicitly marked with the
  /// `@Suite` attribute are synthesized from available type information before
  /// being added to the plan. This trait can be applied to such suites to keep
  /// track of them.
  ///
  /// When this trait is applied to a suite, it is _not_ recursively inherited
  /// by all child suites or tests.
  static var synthesized: Self {
    _synthesizedMarker
  }
}
#endif

extension Test {
  /// Whether or not this instance was synthesized at runtime.
  ///
  /// During test planning, suites that are not explicitly marked with the
  /// `@Suite` attribute are synthesized from available type information before
  /// being added to the plan. For such suites, the value of this property is
  /// `true`.
  ///
  /// In release builds, this information is not tracked and the value of this
  /// property is always `false`.
  ///
  /// ## See Also
  ///
  /// - ``Trait/synthesized``
  @_spi(ForToolsIntegrationOnly)
  public var isSynthesized: Bool {
#if DEBUG
    containsTrait(.synthesized)
#else
    false
#endif
  }
}
