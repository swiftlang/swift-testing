//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Test.Case.ID {
  /// A selection of ``Test/Case/ID`` instances.
  struct Selection: Sendable {
    /// A graph representing the test case IDs in the selection.
    ///
    /// Test case IDs are stored using their ``Test/Case/ID/argumentIDs`` as the
    /// key path. If a child node has value `true`, the key path of that node
    /// represents a test case ID which was explicitly added. Child nodes with
    /// value `false` are intermediary values.
    ///
    /// A test case ID's membership in the selection may be queried using one of
    /// the `contains(_:)` methods.
    private var _argumentIDsGraph: Graph<String, Bool> = .init(value: false)

    /// Initialize an instance of this type with the specified test case IDs.
    ///
    /// - Parameters:
    ///   - testCaseIDs: The test case IDs to include in the selection.
    init(testCaseIDs: some Collection<Test.Case.ID>) {
      for testCaseID in testCaseIDs {
        _argumentIDsGraph.insertValue(true, at: testCaseID.argumentIDs, intermediateValue: false)
      }
    }
  }
}

// MARK: - Membership querying

extension Test.Case.ID.Selection {
  /// Determine if the selection contains the ID for the specified test case.
  ///
  /// - Parameters:
  ///   - testCase: The test case whose ID should be queried.
  ///
  /// - Returns: Whether or not the selection contains the ID for the
  ///   specified test case.
  func contains(_ testCase: Test.Case) -> Bool {
    contains(testCase.id)
  }

  /// Determine if the selection contains the specified test case ID.
  ///
  /// - Parameters:
  ///   - testCaseID: The test case ID to query.
  ///
  /// - Returns: Whether or not the selection contains the specified test case
  ///   ID.
  func contains(_ testCaseID: Test.Case.ID) -> Bool {
    _argumentIDsGraph[testCaseID.argumentIDs] ?? false
  }
}
