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
  /// a known sequence of argument values.
  ///
  /// Instances of this type can be iterated over multiple times.
  struct Generator<S>: Sendable where S: Sequence & Sendable, S.Element: Sendable {
    /// The underlying sequence of argument values.
    ///
    /// The sequence _must_ be iterable multiple times. Hence, factory functions
    /// of ``Test/Case/Argument/List`` accept only _collections_, not sequences.
    /// The constraint on `S` is only to `Sequence` to allow the storage of
    /// computed sequences over collections (such as `CartesianProduct` or
    /// `Zip2Sequence`) that are safe to iterate multiple times.
    private var _sequence: S

    /// A closure that maps an element from `_sequence` to a test case instance.
    ///
    /// - Parameters:
    ///   - element: The element from `_sequence`.
    ///
    /// - Returns: A test case instance that tests `element`.
    private var _mapElement: @Sendable (_ element: S.Element) -> Test.Case
  }
}

// MARK: -

extension Test.Case.Generator {
  /// Initialize an instance of this type that generates exactly one test case.
  ///
  /// - Parameters:
  ///   - testFunction: The test function called by the generated test case.
  init(
    testFunction: nonisolated(nonsending) @escaping @Sendable () async throws -> Void
  ) where S == CollectionOfOne<Void> {
    // A beautiful hack to give us the right number of cases: iterate over a
    // collection containing a single Void value.
    self.init(_sequence: CollectionOfOne(())) {
      Test.Case(values: [], parameters: [], body: testFunction)
    }
  }

  /// Initialize an instance of this type that iterates over the specified
  /// sequence of argument values.
  ///
  /// - Parameters:
  ///   - sequence: The sequence of argument values for which test cases should
  ///     be generated.
  ///   - parameters: The parameters of the test function for which test cases
  ///     should be generated.
  ///   - testFunction: The test function to which each generated test case
  ///     passes an argument value from `sequence`.
  init(
    argumentList: Test.Case.Argument.List<S, S.Element>,
    parameters: [Test.Parameter],
    testFunction: nonisolated(nonsending) @escaping @Sendable (S.Element) async throws -> Void
  ) {
    self.init(_sequence: argumentList.wrappedValue) { element in
      Test.Case(values: argumentList.makeArgumentValues(element), parameters: parameters) {
        try await testFunction(element)
      }
    }
  }

  /// Initialize an instance of this type that iterates over the specified
  /// collections of argument values.
  ///
  /// - Parameters:
  ///   - argumentList1: The first collection of argument values for which test
  ///     cases should be generated.
  ///   - argumentList2: The second collection of argument values for which test
  ///     cases should be generated.
  ///   - parameters: The parameters of the test function for which test cases
  ///     should be generated.
  ///   - testFunction: The test function to which each generated test case
  ///     passes an argument value from the Cartesian product of `argumentList1`
  ///     and `argumentList2`.
  ///
  /// - Bug: The testing library should support variadic generics.
  ///     ([103416861](rdar://103416861))
  init<C1, C2>(
    argumentLists argumentList1: Test.Case.Argument.List<C1, C1.Element>, _ argumentList2: Test.Case.Argument.List<C2, C2.Element>,
    parameters: [Test.Parameter],
    testFunction: nonisolated(nonsending) @escaping @Sendable ((C1.Element, C2.Element)) async throws -> Void
  ) where S == CartesianProduct<C1, C2> {
    let parameterCount = parameters.count
    self.init(_sequence: cartesianProduct(argumentList1.wrappedValue, argumentList2.wrappedValue)) { element in
      var values = argumentList1.makeArgumentValues(element.0) + argumentList2.makeArgumentValues(element.1)
      if parameterCount == 1 && values.count == 2 {
        values = [Test.Case.Argument.Value(tupleOf: values[0], values[1])]
      }
      return Test.Case(values: values, parameters: parameters) {
        try await testFunction(element)
      }
    }
  }
}

// MARK: - Sequence

extension Test.Case.Generator: Sequence {
  func makeIterator() -> some IteratorProtocol<Test.Case> {
    let state = (
      iterator: _sequence.makeIterator(),
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
    _sequence.underestimatedCount
  }
}
