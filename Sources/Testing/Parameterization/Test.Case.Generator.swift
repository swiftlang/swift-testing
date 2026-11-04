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
    /// - Returns: A test case instance that tests `element`, or `nil` if the
    ///   sequence is open-ended (e.g. adapting an iterable type) and has ended.
    private var _mapElement: @Sendable (_ element: S.Element) -> Test.Case?
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
    self.init(_sequence: cartesianProduct(argumentList1.wrappedValue, argumentList2.wrappedValue)) { element in
      let values = argumentList1.makeArgumentValues(element.0) + argumentList2.makeArgumentValues(element.1)
      return Test.Case(values: values, parameters: parameters) {
        try await testFunction(element)
      }
    }
  }

  /// Initialize an instance of this type that iterates over the specified
  /// inline array of argument values.
  ///
  /// - Parameters:
  ///   - argumentList: An argument list representing the set of argument values
  ///     for which test cases should be generated.
  ///   - parameters: The parameters of the test function for which test cases
  ///     should be generated.
  ///   - testFunction: The test function to which each generated test case
  ///     passes an argument value from `argumentList`.
  @available(_iterableAPI, *)
  init<I>(
    argumentList: consuming Test.Case.Argument.List<I, I.Element>,
    parameters: [Test.Parameter],
    testFunction: nonisolated(nonsending) @escaping @Sendable (borrowing I.Element) async throws -> Void
  ) where S == Range<Int>, I: Sendable & Iterable & ~Copyable, I.Element: Sendable & ~Copyable, I.BorrowingIterator == Span<I.Element>.BorrowingIterator {
    let argumentList = consume argumentList
    self.init(_sequence: 0 ..< argumentList.wrappedValue.count) { i in
      let values = argumentList.makeArgumentValues(argumentList.wrappedValue[i])
      return Test.Case(values: values, parameters: parameters) {
        try await testFunction(argumentList.wrappedValue[i])
      }
    }
  }

  /// Initialize an instance of this type that iterates over the specified
  /// inline array of argument values.
  ///
  /// - Parameters:
  ///   - argumentList1: The first argument list.
  ///   - argumentList2: The second argument list.
  ///   - parameters: The parameters of the test function for which test cases
  ///     should be generated.
  ///   - testFunction: The test function to which each generated test case
  ///     passes an argument value from the Cartesian product of `argumentList1`
  ///     and `argumentList2`.
  @available(_iterableAPI, *)
  init<C1, C2>(
    argumentLists argumentList1: consuming Test.Case.Argument.List<C1, C1.Element>, _ argumentList2: consuming Test.Case.Argument.List<C2, C2.Element>,
    parameters: [Test.Parameter],
    testFunction: nonisolated(nonsending) @escaping @Sendable (borrowing C1.Element, borrowing C2.Element) async throws -> Void
  ) where S == CartesianProduct<Range<Int>, Range<Int>>, C1: Sendable & Iterable & ~Copyable, C1.Element: Sendable & ~Copyable, C1.BorrowingIterator == Span<C1.Element>.BorrowingIterator, C2: Sendable & Iterable & ~Copyable, C2.Element: Sendable & ~Copyable, C2.BorrowingIterator == Span<C2.Element>.BorrowingIterator {
    let argumentList1 = consume argumentList1
    let argumentList2 = consume argumentList2
    self.init(_sequence: cartesianProduct(0 ..< argumentList1.wrappedValue.count, 0 ..< argumentList2.wrappedValue.count)) { i1, i2 in
      let values = argumentList1.makeArgumentValues(argumentList1.wrappedValue[i1]) + argumentList2.makeArgumentValues(argumentList2.wrappedValue[i2])
      return Test.Case(values: values, parameters: parameters) {
        try await testFunction(argumentList1.wrappedValue[i1], argumentList2.wrappedValue[i2])
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
      guard let element = state.iterator.next(),
            var testCase = _mapElement(element) else {
        return nil
      }

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
