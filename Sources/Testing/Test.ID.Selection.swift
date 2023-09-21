//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Test.ID {
  /// A selection of ``Test/ID`` elements.
  ///
  /// This internally stores the test IDs using a `Graph` for more efficient
  /// storage and membership querying.
  ///
  /// Note that this type represents a selection in the abstract, and may
  /// represent tests which have been selected to be run or be skipped.
  struct Selection: Sendable {
    /// A graph representing the test IDs in the selection.
    ///
    /// If a child node has value `true`, the key path of that node represents a
    /// test ID which was explicitly added. Child nodes with value `false` are
    /// intermediary values.
    ///
    /// A test ID's membership in the selection may be queried using one of the
    /// `contains(_:)` methods.
    private var _testIDsGraph = Graph<String, Bool>(value: false)

    /// A `Set` representing the test IDs which have been explicitly added.
    ///
    /// May include test IDs that are redundant and overlap with others.
    private(set) var testIDs: Set<Test.ID>

    /// Initialize an instance of this type with the specified test IDs.
    ///
    /// - Parameters:
    ///   - testIDs: The test IDs to include in the selection.
    init(testIDs: some Collection<Test.ID>) {
      self.testIDs = Set(testIDs)
      _testIDsGraph = .init(value: false)
      for testID in self.testIDs {
        _testIDsGraph.insertValue(true, at: testID.keyPathRepresentation, intermediateValue: false)
      }
    }

    /// Determine if the selection contains the ID for the specified test.
    ///
    /// - Parameters:
    ///   - test: The test whose ID should be queried.
    ///
    /// - Returns: Whether or not the selection contains the ID for the
    ///   specified test.
    ///
    /// A test ID is considered contained in the selection if it has been
    /// explicitly added or if it has a descendant or ancestor which has been
    /// explicitly added.
    func contains(_ test: Test) -> Bool {
      contains(test.id)
    }

    /// Determine if the selection contains a specified test ID.
    ///
    /// - Parameters:
    ///   - testID: The test ID to query.
    ///
    /// - Returns: Whether or not the selection contains the specified test ID.
    ///
    /// A test ID is considered contained in the selection if it has been
    /// explicitly added or if it has a descendant or ancestor which has been
    /// explicitly added.
    func contains(_ testID: Test.ID) -> Bool {
      contains(testID.keyPathRepresentation)
    }

    /// Determine if the selection contains a test ID with the specified fully-
    /// qualified name components.
    ///
    /// - Parameters:
    ///   - fullyQualifiedNameComponents: The fully-qualified name components of
    ///     the test ID to query.
    ///
    /// - Returns: Whether or not the selection contains a test ID with the
    ///   specified fully-qualified name components.
    ///
    /// A test ID is considered contained in the selection if it has been
    /// explicitly added or if it has a descendant or ancestor which has been
    /// explicitly added.
    func contains(_ fullyQualifiedNameComponents: some Collection<String>) -> Bool {
      var isContained = false

      for value in _testIDsGraph.takeValues(at: fullyQualifiedNameComponents) {
        switch value {
        case .some(false):
          isContained = true
        case .some(true):
          return true
        case nil:
          return false
        }
      }

      return isContained
    }
  }
}
