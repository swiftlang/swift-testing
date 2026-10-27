//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Test.Case {
  /// A type describing a lazily-generated sequence of test cases generated from
  /// a known collection of argument values.
  ///
  /// Instances of this type can be iterated over multiple times.
  ///
  /// @Comment {
  ///   - Bug: The testing library should support variadic generics.
  ///     ([103416861](rdar://103416861))
  /// }
  struct Generator<S>: Sendable where S: Sequence & Sendable, S.Element: Sendable {
    /// The underlying argument list.
    private var _argumentList: Test.Case.Argument.List<S>

    /// A closure that maps an element from `_sequence` to a test case instance.
    ///
    /// - Parameters:
    ///   - element: The element from `_sequence`.
    ///
    /// - Returns: A test case instance that tests `element`.
    private var _mapElement: @Sendable (_ element: S.Element) -> Test.Case

    /// Initialize an instance of this type that iterates over the specified
    /// sequence of argument values.
    ///
    /// - Parameters:
    ///   - sequence: The sequence of argument values for which test cases
    ///     should be generated.
    ///   - parameters: The parameters of the test function for which test cases
    ///     should be generated.
    ///   - testFunction: The test function to which each generated test case
    ///     passes an argument value from `sequence`.
    init(
      argumentList: Test.Case.Argument.List<S>,
      parameters: [Test.Parameter],
      testFunction: nonisolated(nonsending) @escaping @Sendable (S.Element) async throws -> Void
    ) {
      _argumentList = argumentList
      _mapElement = { element in
        return Test.Case(values: argumentList.makeArgumentValues(element), parameters: parameters) {
          try await testFunction(element)
        }
      }
    }

    /// Initialize an instance of this type that generates exactly one test
    /// case.
    ///
    /// - Parameters:
    ///   - testFunction: The test function called by the generated test case.
    init(
      testFunction: nonisolated(nonsending) @escaping @Sendable () async throws -> Void
    ) where S == CollectionOfOne<Void> {
      // A beautiful hack to give us the right number of cases: iterate over a
      // collection containing a single Void value.
      let argumentList = Test.Case.Argument.List(CollectionOfOne(())) { [] }
      self.init(argumentList: argumentList, parameters: [], testFunction: testFunction)
    }

    /// Initialize an instance of this type that iterates over the specified
    /// collections of argument values.
    ///
    /// - Parameters:
    ///   - collection1: The first collection of argument values for which test
    ///     cases should be generated.
    ///   - collection2: The second collection of argument values for which test
    ///     cases should be generated.
    ///   - parameters: The parameters of the test function for which test cases
    ///     should be generated.
    ///   - testFunction: The test function to which each generated test case
    ///     passes an argument value from `collection`.
    init<C1, C2>(
      argumentLists collection1: Test.Case.Argument.List<C1>, _ collection2: Test.Case.Argument.List<C2>,
      parameters: [Test.Parameter],
      testFunction: nonisolated(nonsending) @escaping @Sendable (C1.Element, C2.Element) async throws -> Void
    ) where S == CartesianProduct<C1, C2> {
      let cartesianProduct = Test.Case.Argument.List(cartesianProduct(collection1.sequence, collection2.sequence)) { element in
        collection1.makeArgumentValues(element.0) + collection2.makeArgumentValues(element.1)
      }
      self.init(argumentList: cartesianProduct, parameters: parameters, testFunction: testFunction)
    }
  }
}

// MARK: - Sequence

extension Test.Case.Generator: Sequence {
  func makeIterator() -> some IteratorProtocol<Test.Case> {
    let state = (
      iterator: _argumentList.sequence.makeIterator(),
      testCaseIDs: [Test.Case.ID: Int](minimumCapacity: underestimatedCount)
    )

    return sequence(state: state) { state in
      guard let element = state.iterator.next() else {
        return nil
      }

      var testCase = _mapElement(element)

      if testCase.isParameterized {
        // Store the original, unmodified test case ID. We're about to modify a
        // property which affects it, and we want to update state based on the
        // original one.
        let testCaseID = testCase.id

        // Ensure test cases with identical IDs each have a unique discriminator.
        let discriminator = state.testCaseIDs[testCaseID, default: 0]
        testCase.discriminator = discriminator
        state.testCaseIDs[testCaseID] = discriminator + 1
      }

      return testCase
    }
  }

  var underestimatedCount: Int {
    _argumentList.sequence.underestimatedCount
  }
}
