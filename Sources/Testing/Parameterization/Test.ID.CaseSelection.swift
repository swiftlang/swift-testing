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
  /// A type representing a selection of test cases grouped by their associated
  /// test.
  struct CaseSelection: Sendable {
    /// A graph representing the test IDs and their selected test case IDs.
    ///
    /// Test IDs are stored with any associated `sourceLocation` removed, since
    /// that is how users and tools reference tests.
    private var _graph = Graph<String, Test.Case.ID.Selection?>(value: nil)
  }
}

// MARK: - Membership querying

extension Test.ID.CaseSelection {
  /// Access the selected test case IDs for the specified test for reading and
  /// writing.
  ///
  /// - Parameters:
  ///   - test: The test whose selected test case IDs should be accessed.
  ///
  /// - Returns: The selected test case IDs for the specified test.
  subscript(test: Test) -> Test.Case.ID.Selection? {
    get {
      self[test.id]
    }
    set {
      self[test.id] = newValue
    }
  }

  /// Access the selected test case IDs for the specified test ID for reading
  /// and writing.
  ///
  /// - Parameters:
  ///   - test: The test ID whose selected test case IDs should be accessed.
  ///
  /// - Returns: The selected test case IDs for the specified test ID.
  subscript(testID: Test.ID) -> Test.Case.ID.Selection? {
    get {
      _graph[testID.removingSourceLocation.keyPathRepresentation]
    }
    set {
      _graph[testID.removingSourceLocation.keyPathRepresentation] = newValue
    }
  }
}

extension Test.ID {
  /// A new test ID made by assigning this instance's `sourceLocation` property
  /// to `nil`.
  fileprivate var removingSourceLocation: Self {
    var testID = self
    testID.sourceLocation = nil
    return testID
  }
}
