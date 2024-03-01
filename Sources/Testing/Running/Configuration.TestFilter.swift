//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ForToolsIntegrationOnly)
extension Configuration {
  /// A type that handles filtering tests.
  ///
  /// Instances of this type provide an abstraction over arbitrary
  /// test-filtering functions as well as optimized paths for specific common
  /// use cases such as filtering by test ID.
  public struct TestFilter: Sendable {
    /// An enumeration describing how to interpret the result of the underlying
    /// predicate function when applied to a test.
    enum Membership: Sendable {
      /// The underlying predicate function determines if a test is included in
      /// the result.
      case including

      /// The underlying predicate function determines if a test is excluded
      /// from the result.
      case excluding
    }

    /// An enumeration describing the various kinds of test filter.
    fileprivate enum Kind: Sendable {
      /// The test filter has no effect.
      ///
      /// All tests are allowed when passed to a test filter with this kind.
      case unfiltered

      /// The test filter contains a precomputed selection of test IDs.
      ///
      /// - Parameters:
      ///   - testIDs: The set of test IDs to predicate tests against.
      ///   - membership: How to interpret the result when predicating tests.
      case precomputed(_ testIDs: Test.ID.Selection, membership: Membership)

      /// The test filter is an arbitrary predicate function.
      ///
      /// - Parameters:
      ///   - predicate: The function to predicate tests against.
      ///   - membership: How to interpret the result when predicating tests.
      case function(_ predicate: @Sendable (borrowing Test) -> Bool, membership: Membership)

      /// The test filter is a combination of other test filters.
      ///
      /// - Parameters:
      ///   - lhs: The first test filter's kind.
      ///   - rhs: The second test filter's kind.
      ///   - op: The operator to apply when combining the results of the two
      ///     filters.
      ///
      /// The result of a test filter with this kind is the combination of the
      /// results of its subfilters using `operator`.
      indirect case combined(_ lhs: Kind, _ rhs: Kind, _ op: CombinationOperator)
    }

    /// The kind of test filter.
    private var _kind: Kind

    /// Whether or not to include tests with the `.hidden` trait when filtering
    /// tests.
    ///
    /// By default, any test with the `.hidden` trait is treated as if it did
    /// not pass the test filter's predicate function. When the testing library
    /// is running its own tests, it sometimes uses this property to enable
    /// discovery of fixture tests.
    ///
    /// The value of this property is inherited from `self` when using
    /// ``combining(with:)`` or ``combine(with:)`` (i.e. the left-hand test
    /// filter takes precedence.)
    ///
    /// This property is not part of the public interface of the testing
    /// library.
    var includeHiddenTests = false
  }
}

// MARK: - Initializers

extension Configuration.TestFilter {
  /// A test filter that does not perform any filtering.
  ///
  /// This test filter allows all tests to run; it is the default test filter if
  /// another is not specified.
  public static var unfiltered: Self {
    Self(_kind: .unfiltered)
  }

  /// Initialize this instance to filter tests to those specified by a set of
  /// test IDs.
  ///
  /// - Parameters:
  ///   - testIDs: A set of test IDs to be filtered.
  public init(including testIDs: some Collection<Test.ID>) {
    let selection = Test.ID.Selection(testIDs: testIDs)
    self.init(_kind: .precomputed(selection, membership: .including))
  }

  /// Initialize this instance to filter tests to those _not_ specified by a set
  /// of test IDs.
  ///
  /// - Parameters:
  ///   - selection: A set of test IDs to be excluded.
  public init(excluding testIDs: some Collection<Test.ID>) {
    let selection = Test.ID.Selection(testIDs: testIDs)
    self.init(_kind: .precomputed(selection, membership: .excluding))
  }

  /// Initialize this instance from an arbitrary function.
  ///
  /// - Parameters:
  ///   - membership: How to interpret the result when predicating tests.
  ///   - predicate: The function to predicate tests against.
  init(membership: Membership, matching predicate: @escaping @Sendable (borrowing Test) -> Bool) {
    self.init(_kind: .function(predicate, membership: membership))
  }

  /// Initialize this instance to operate based on a set of tags.
  ///
  /// - Parameters:
  ///   - tags: The set of tags to either include or exclude.
  ///   - anyOf: Whether tests must have _any_ of the tags in `tags` (as opposed
  ///     to all of them.)
  ///   - membership: How to interpret the result when predicating tests.
  init(tags: some Collection<Tag>, anyOf: Bool, membership: Membership) {
    let tags = Set(tags)
    self.init(membership: membership) { test in
      if anyOf {
        !test.tags.isDisjoint(with: tags) // .intersects()
      } else {
        test.tags.isSuperset(of: tags)
      }
    }
  }

  /// Initialize this instance to include tests with a given set of tags.
  ///
  /// - Parameters:
  ///   - tags: The set of tags to include.
  ///
  /// Matching tests have had _any_ of the tags in `tags` added to them.
  public init(includingAnyOf tags: some Collection<Tag>) {
    self.init(tags: tags, anyOf: true, membership: .including)
  }

  /// Initialize this instance to exclude tests with a given set of tags.
  ///
  /// - Parameters:
  ///   - tags: The set of tags to exclude.
  ///
  /// Matching tests have had _any_ of the tags in `tags` added to them.
  public init(excludingAnyOf tags: some Collection<Tag>) {
    self.init(tags: tags, anyOf: true, membership: .excluding)
  }

  /// Initialize this instance to include tests with a given set of tags.
  ///
  /// - Parameters:
  ///   - tags: The set of tags to include.
  ///
  /// Matching tests have had _all_ of the tags in `tags` added to them.
  public init(includingAllOf tags: some Collection<Tag>) {
    self.init(tags: tags, anyOf: false, membership: .including)
  }

  /// Initialize this instance to exclude tests with a given set of tags.
  ///
  /// - Parameters:
  ///   - tags: The set of tags to exclude.
  ///
  /// Matching tests have had _all_ of the tags in `tags` added to them.
  public init(excludingAllOf tags: some Collection<Tag>) {
    self.init(tags: tags, anyOf: false, membership: .excluding)
  }
}

// MARK: - Operations

extension Configuration.TestFilter.Kind {
  /// Apply this test filter to a test graph and remove tests that should not be
  /// included.
  ///
  /// - Parameters:
  ///   - testGraph: The test graph to filter.
  ///
  /// - Returns: A copy of `testGraph` with filtered tests replaced with `nil`.
  ///
  /// This function provides the bulk of the implementation of
  /// ``Configuration/TestFilter/apply(to:)``.
  fileprivate func apply(to testGraph: Graph<String, Test?>) -> Graph<String, Test?> {
    switch self {
    case .unfiltered:
      return testGraph
    case let .precomputed(selection, membership):
      return testGraph.mapValues { test in
        guard let test else {
          return nil
        }
        return switch membership {
        case .including:
          selection.contains(test) ? test : nil
        case .excluding:
          !selection.contains(test, inferAncestors: false) ? test : nil
        }
      }
    case let .function(function, membership):
      // When filtering by predicate function, it is necessary to determine
      // membership AFTER resolving all tests, since we do not know what the
      // function is going to do with the test and it needs the test instance in
      // order to do anything useful, whereas test IDs can be constructed
      // independently of the tests they identify.
      //
      // The most expedient path forward is to construct a test ID selection
      // containing matching tests, then translate it into a new instance of
      // TestFilter, then finally run that test filter to modify the graph.
      let testIDs = testGraph
        .compactMap(\.value).lazy
        .filter(function)
        .map(\.id)
      let selection = Test.ID.Selection(testIDs: testIDs)
      return Self.precomputed(selection, membership: membership).apply(to: testGraph)
    case let .combined(lhs, rhs, op):
      return zip(
        lhs.apply(to: testGraph),
        rhs.apply(to: testGraph)
      ).mapValues(op.functionValue)
    }
  }
}

extension Configuration.TestFilter {
  /// Apply this test filter to a test graph and remove tests that should not be
  /// included.
  ///
  /// - Parameters:
  ///   - testGraph: The test graph to filter.
  ///
  /// - Returns: A copy of `testGraph` with filtered tests replaced with `nil`.
  func apply(to testGraph: Graph<String, Test?>) -> Graph<String, Test?> {
    var result = _kind.apply(to: testGraph)

    // After performing the test function, run through one more time and remove
    // hidden tests. (Note that this property's value is not recursively set on
    // combined test filters. It is only consulted on the outermost call to
    // apply(to:), not in _apply(to:).
    if !includeHiddenTests {
      result = result.mapValues { test in
        (test?.isHidden == true) ? nil : test
      }
    }

    return result
  }
}

// MARK: - Combining

extension Configuration.TestFilter {
  /// An enumeration describing operators that can be used to combine test
  /// filters when using ``combining(with:using:)`` or ``combine(with:using:)``.
  public enum CombinationOperator: Sendable {
    /// Both subfilters must allow a test for it to be allowed in the combined
    /// test filter.
    ///
    /// This operator is equivalent to `&&`.
    case and

    /// Either subfilter must allow a test for it to be allowed in the combined
    /// test filter.
    ///
    /// This operator is equivalent to `||`.
    case or

    /// The equivalent of this instance as a callable function.
    fileprivate var functionValue: @Sendable (Test?, Test?) -> Test? {
      switch self {
      case .and:
        return { lhs, rhs in
          if lhs != nil && rhs != nil {
            lhs
          } else {
            nil
          }
        }
      case .or:
        return { lhs, rhs in
          lhs ?? rhs
        }
      }
    }
  }
  /// Combine this test filter with another one.
  ///
  /// - Parameters:
  ///   - other: Another test filter.
  ///   - op: The operator to apply when combining the results of the two
  ///     filters. By default, `.and` is used.
  ///
  /// - Returns: A copy of `self` combined with `other`.
  ///
  /// The resulting test filter predicates tests against both `self` and `other`
  /// and includes them in results if they pass both.
  public func combining(with other: Self, using op: CombinationOperator = .and) -> Self {
    var result = switch (_kind, other._kind) {
    case (.unfiltered, _):
      other
    case (_, .unfiltered):
      self
    default:
      Self(_kind: .combined(_kind, other._kind, op))
    }
    result.includeHiddenTests = includeHiddenTests

    return result
  }

  /// Combine this test filter with another one.
  ///
  /// - Parameters:
  ///   - other: Another test filter.
  ///   - op: The operator to apply when combining the results of the two
  ///     filters. By default, `.and` is used.
  ///
  /// This instance is modified in place. Afterward, it predicates tests against
  /// both its previous test function and the one from `other` and includes them
  /// in results if they pass both.
  public mutating func combine(with other: Self, using op: CombinationOperator = .and) {
    self = combining(with: other, using: op)
  }
}
