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
      case testIDs(_ testIDs: Set<Test.ID>, membership: Membership)

      /// The test filter contains a set of tags to predicate tests against.
      ///
      /// - Parameters:
      ///   - tags: The set of test tags to predicate tests against.
      ///   - anyOf: Whether to require that tests have any (`true`) or all
      ///     (`false`) of the specified tags.
      ///   - membership: How to interpret the result when predicating tests.
      case tags(_ tags: Set<Tag>, anyOf: Bool, membership: Membership)

      /// The test filter contains a pattern to predicate test IDs against.
      ///
      /// - Parameters:
      ///   - patterns: The patterns to predicate test IDs against.
      ///   - membership: How to interpret the result when predicating tests.
      case patterns(_ patterns: [String], membership: Membership)

      /// The test filter is a combination of other test filter kinds.
      ///
      /// - Parameters:
      ///   - lhs: The first test filter's kind.
      ///   - rhs: The second test filter's kind.
      ///   - op: The operator to apply when combining the results of the two
      ///     filters.
      ///
      /// The result of a test filter with this kind is the combination of the
      /// results of its subfilters using `op`.
      indirect case combination(_ lhs: Self, _ rhs: Self, _ op: CombinationOperator)
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
    self.init(_kind: .testIDs(Set(testIDs), membership: .including))
  }

  /// Initialize this instance to filter tests to those _not_ specified by a set
  /// of test IDs.
  ///
  /// - Parameters:
  ///   - testIDs: A set of test IDs to be excluded.
  public init(excluding testIDs: some Collection<Test.ID>) {
    self.init(_kind: .testIDs(Set(testIDs), membership: .excluding))
  }

  /// Initialize this instance to represent a pattern expression matched against
  /// a test's ID.
  ///
  /// - Parameters:
  ///   - membership: How to interpret the result when predicating tests.
  ///   - patterns: The patterns, expressed as a `Regex`-compatible regular
  ///     expressions, to match test IDs against.
  @available(_regexAPI, *)
  init(membership: Membership, matchingAnyOf patterns: some Sequence<String>) throws {
    // Validate each regular expression by attempting to initialize a `Regex`
    // representing it, but do not preserve it. This type only represents
    // the pattern in the abstract, and is not responsible for actually
    // applying it to a test graph — that happens later during planning.
    //
    // Performing this validation here currently makes such errors easier to
    // surface when using the SwiftPM entry point. But longer-term, we should
    // make the planning phase throwing and propagate errors from there instead.
    for pattern in patterns {
      _ = try Regex(pattern)
    }

    self.init(_kind: .patterns(Array(patterns), membership: membership))
  }

  /// Initialize this instance to include tests with a given set of tags.
  ///
  /// - Parameters:
  ///   - tags: The set of tags to include.
  ///
  /// Matching tests have had _any_ of the tags in `tags` added to them.
  public init(includingAnyOf tags: some Collection<Tag>) {
    self.init(_kind: .tags(Set(tags), anyOf: true, membership: .including))
  }

  /// Initialize this instance to exclude tests with a given set of tags.
  ///
  /// - Parameters:
  ///   - tags: The set of tags to exclude.
  ///
  /// Matching tests have had _any_ of the tags in `tags` added to them.
  public init(excludingAnyOf tags: some Collection<Tag>) {
    self.init(_kind: .tags(Set(tags), anyOf: true, membership: .excluding))
  }

  /// Initialize this instance to include tests with a given set of tags.
  ///
  /// - Parameters:
  ///   - tags: The set of tags to include.
  ///
  /// Matching tests have had _all_ of the tags in `tags` added to them.
  public init(includingAllOf tags: some Collection<Tag>) {
    self.init(_kind: .tags(Set(tags), anyOf: false, membership: .including))
  }

  /// Initialize this instance to exclude tests with a given set of tags.
  ///
  /// - Parameters:
  ///   - tags: The set of tags to exclude.
  ///
  /// Matching tests have had _all_ of the tags in `tags` added to them.
  public init(excludingAllOf tags: some Collection<Tag>) {
    self.init(_kind: .tags(Set(tags), anyOf: false, membership: .excluding))
  }
}

// MARK: - Operations

extension Configuration.TestFilter {
  /// An enumeration which represents filtering logic to be applied to a test
  /// graph.
  fileprivate enum Operation<Item>: Sendable where Item: _FilterableItem {
    /// A filter operation which has no effect.
    ///
    /// All tests are allowed when this operation is applied.
    case unfiltered

    /// A filter operation which accepts tests included in a precomputed
    /// selection of test IDs.
    ///
    /// - Parameters:
    ///   - testIDs: The set of test IDs to predicate tests against.
    ///   - membership: How to interpret the result when predicating tests.
    case precomputed(_ testIDs: Test.ID.Selection, membership: Membership)

    /// A filter operation which accepts tests which satisfy an arbitrary
    /// predicate function.
    ///
    /// - Parameters:
    ///   - predicate: The function to predicate tests against.
    ///   - membership: How to interpret the result when predicating tests.
    case function(_ predicate: @Sendable (borrowing Item) -> Bool, membership: Membership)

    /// A filter operation which is a combination of other operations.
    ///
    /// - Parameters:
    ///   - lhs: The first test filter operation.
    ///   - rhs: The second test filter operation.
    ///   - op: The operator to apply when combining the results of the two
    ///     filter operations.
    ///
    /// The result of applying this filter operation is the combination of
    /// applying the results of its sub-operations using `op`.
    indirect case combination(_ lhs: Self, _ rhs: Self, _ op: CombinationOperator)
  }
}

extension Configuration.TestFilter.Kind {
  /// An operation which implements the filtering logic for this test filter
  /// kind.
  ///
  /// - Throws: Any error encountered while generating an operation for this
  ///   test filter kind. One example is the creation of a `Regex` from a
  ///   `.pattern` kind: if the pattern is not a valid regular expression, an
  ///   error will be thrown.
  func operation<T>(itemType: T.Type = T.self) throws -> Configuration.TestFilter.Operation<T> where T: _FilterableItem {
    switch self {
    case .unfiltered:
      return .unfiltered
    case let .testIDs(testIDs, membership):
      return .precomputed(Test.ID.Selection(testIDs: testIDs), membership: membership)
    case let .tags(tags, anyOf, membership):
      let predicate: @Sendable (borrowing T) -> Bool = if anyOf {
        { !$0.tags.isDisjoint(with: tags) /* .intersects() */ }
      } else {
        { $0.tags.isSuperset(of: tags) }
      }
      return .function(predicate, membership: membership)
    case let .patterns(patterns, membership):
      guard #available(_regexAPI, *) else {
        throw SystemError(description: "Filtering by regular expression matching is unavailable")
      }

      nonisolated(unsafe) let regexes = try patterns.map(Regex.init)
      return .function({ item in
        let id = String(describing: item.test.id)
        return regexes.contains { id.contains($0) }
      }, membership: membership)
    case let .combination(lhs, rhs, op):
      return try .combination(lhs.operation(), rhs.operation(), op)
    }
  }
}

extension Configuration.TestFilter.Operation {
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
  fileprivate func apply(to testGraph: Graph<String, Item?>) -> Graph<String, Item?> {
    switch self {
    case .unfiltered:
      return testGraph
    case let .precomputed(selection, membership):
      switch membership {
      case .including:
        return testGraph.mapValues { _, item in
          guard let item else {
            return nil
          }
          return selection.contains(item.test) ? item : nil
        }
      case .excluding:
        return testGraph.mapValues { _, item in
          guard let item else {
            return nil
          }
          return !selection.contains(item.test, inferAncestors: false) ? item : nil
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
        .map(\.test.id)
      let selection = Test.ID.Selection(testIDs: testIDs)
      return Self.precomputed(selection, membership: membership).apply(to: testGraph)
    case let .combination(lhs, rhs, op):
      return zip(
        lhs.apply(to: testGraph),
        rhs.apply(to: testGraph)
      ).mapValues { _, value in
        op(value.0, value.1)
      }
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
  func apply(to testGraph: Graph<String, Test?>) throws -> Graph<String, Test?> {
    var result: Graph<String, Test?>

    if _kind.requiresTraitPropagation {
      // Convert the specified test graph to a graph of filter items temporarily
      // while performing filtering, and apply inheritance for the properties
      // which are relevant when performing filtering (e.g. tags).
      var filterItemGraph = testGraph.mapValues { $1.map(FilterItem.init(test:)) }
      _recursivelyApplyFilterProperties(to: &filterItemGraph)

      result = try _kind.operation().apply(to: filterItemGraph)
        .mapValues { $1?.test }
    } else {
      result = try _kind.operation().apply(to: testGraph)
    }

    // After filtering, run through one more time and prune the test graph to
    // remove any unnecessary nodes, since that reduces work in later stages of
    // planning.
    //
    // If `includeHiddenTests` is false, this will also remove any nodes
    // representing hidden tests. (Note that the value of the
    // `includeHiddenTests` property is not recursively set on combined test
    // filters. It is only consulted on the outermost call to apply(to:), not in
    // _apply(to:).)
    _recursivelyPruneTestGraph(&result)

    return result
  }

  /// Recursively apply filtering-related properties from test suites to their
  /// children in a graph.
  ///
  /// - Parameters:
  ///   - graph: The graph of filter items to modify.
  ///   - tags: Tags from the parent of `graph` which `graph` should inherit.
  private func _recursivelyApplyFilterProperties(to graph: inout Graph<String, FilterItem?>, tags: Set<Tag> = []) {
    var tags = tags
    if let item = graph.value {
      tags.formUnion(item.tags)
      graph.value?.tags = tags
    }

    for (key, var childGraph) in graph.children {
      _recursivelyApplyFilterProperties(to: &childGraph, tags: tags)
      graph.children[key] = childGraph
    }
  }

  /// Recursively prune a test graph to remove unnecessary nodes.
  ///
  /// - Parameters:
  ///   - testGraph: The graph of tests to modify.
  private func _recursivelyPruneTestGraph(_ graph: inout Graph<String, Test?>) {
    // The recursive function. This is structured as a distinct function to
    // ensure that the root node itself is always preserved (despite its value
    // being `nil`).
    func pruneGraph(_ graph: Graph<String, Test?>) -> Graph<String, Test?>? {
      if !includeHiddenTests, let test = graph.value, test.isHidden {
        return nil
      }

      var graph = graph
      for (key, childGraph) in graph.children {
        graph.children[key] = pruneGraph(childGraph)
      }
      if graph.value == nil && graph.children.isEmpty {
        return nil
      }
      return graph
    }

    for (key, childGraph) in graph.children {
      graph.children[key] = pruneGraph(childGraph)
    }
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

    /// Evaluate this combination operator with two optional operands.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand argument
    ///   - rhs: The right-hand argument.
    ///
    /// - Returns: The combined result of evaluating this operator.
    fileprivate func callAsFunction<T>(_ lhs: T?, _ rhs: T?) -> T? where T: _FilterableItem {
      switch self {
      case .and:
        if lhs != nil && rhs != nil {
          lhs
        } else {
          nil
        }
      case .or:
        lhs ?? rhs
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
      Self(_kind: .combination(_kind, other._kind, op))
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

// MARK: - Filterable types

extension Configuration.TestFilter.Kind {
  /// Whether this kind of test filter requires knowledge of test traits.
  ///
  /// If the value of this property is `true`, the values of a test graph must
  /// be converted to `FilterItem` and have trait information recursively
  /// propagated before the filter can be applied, or else the results may be
  /// inaccurate. This facilitates a performance optimization where trait
  /// propagation can be skipped for filters which don't require such knowledge.
  fileprivate var requiresTraitPropagation: Bool {
    switch self {
    case .unfiltered,
         .testIDs,
         .patterns:
      false
    case .tags:
      true
    case let .combination(lhs, rhs, _):
      lhs.requiresTraitPropagation || rhs.requiresTraitPropagation
    }
  }
}

/// A protocol representing a value which can be filtered using
/// ``Configuration/TestFilter-swift.struct``.
private protocol _FilterableItem {
  /// The test this item represents.
  var test: Test { get }

  /// The complete set of tags for ``test``, including those inherited from
  /// containing suites.
  var tags: Set<Tag> { get }
}

extension Test: _FilterableItem {
  var test: Test {
    self
  }
}

/// An item representing a test and its filtering-related properties.
///
/// Instances of this type are needed when applying a test graph to a kind of
/// filter for which the value of the `requiresFilterItemConversion` property
/// is `true`.
fileprivate struct FilterItem: _FilterableItem {
  var test: Test

  var tags: Set<Tag>

  init(test: Test) {
    self.test = test
    self.tags = test.tags
  }
}
