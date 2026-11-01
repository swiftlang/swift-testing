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
  final class Generator<S, E>: Sendable where S: Sendable & ~Copyable, E: Sendable & ~Copyable {
    /// The underlying argument list.
    private let _argumentList: Test.Case.Argument.List<S, E>

    /// A closure that maps an element from `_sequence` to a test case instance.
    ///
    /// - Parameters:
    ///   - element: The element from `_sequence`.
    ///
    /// - Returns: A test case instance that tests `element`.
    private let _mapElement: @Sendable (_ element: borrowing E) -> Test.Case

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
      argumentList: Test.Case.Argument.List<S, S.Element>,
      parameters: [Test.Parameter],
      testFunction: nonisolated(nonsending) @escaping @Sendable (S.Element) async throws -> Void
    ) where S: Sequence, E == S.Element {
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
    convenience init(
      testFunction: nonisolated(nonsending) @escaping @Sendable () async throws -> Void
    ) where S == CollectionOfOne<Void>, E == Void {
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
    convenience init<C1, C2>(
      argumentLists collection1: Test.Case.Argument.List<C1, C1.Element>, _ collection2: Test.Case.Argument.List<C2, C2.Element>,
      parameters: [Test.Parameter],
      testFunction: nonisolated(nonsending) @escaping @Sendable (C1.Element, C2.Element) async throws -> Void
    ) where S == CartesianProduct<C1, C2>, E == (C1.Element, C2.Element) {
      let cartesianProduct = Test.Case.Argument.List(cartesianProduct(collection1.sequence, collection2.sequence)) { element in
        collection1.makeArgumentValues(element.0) + collection2.makeArgumentValues(element.1)
      }
      self.init(argumentList: cartesianProduct, parameters: parameters, testFunction: testFunction)
    }
  }
}

extension Test.Case.Generator where S: ~Copyable, E: ~Copyable {
  private func _makeTestCase(from element: borrowing E, testCaseIDs: inout [Test.Case.ID: Int]) -> Test.Case {
    var testCase = _mapElement(element)

    if testCase.isParameterized {
      // Store the original, unmodified test case ID. We're about to modify a
      // property which affects it, and we want to update state based on the
      // original one.
      let testCaseID = testCase.id

      // Ensure test cases with identical IDs each have a unique discriminator.
      let discriminator = testCaseIDs[testCaseID, default: 0]
      testCase.discriminator = discriminator
      testCaseIDs[testCaseID] = discriminator + 1
    }

    return testCase
  }
}

// MARK: - Sequence

extension Test.Case.Generator: Sequence where S: Sequence, E == S.Element {
  func makeIterator() -> some IteratorProtocol<Test.Case> {
    let state = (
      iterator: _argumentList.sequence.makeIterator(),
      testCaseIDs: [Test.Case.ID: Int](minimumCapacity: underestimatedCount)
    )

    return sequence(state: state) { state in
      guard let element = state.iterator.next() else {
        return nil
      }
      return self._makeTestCase(from: element, testCaseIDs: &state.testCaseIDs)
    }
  }

  var underestimatedCount: Int {
    _argumentList.sequence.underestimatedCount
  }
}

// MARK: - Iterable

@available(anyAppleOS 27, *)
extension Test.Case.Generator: Iterable where S: Iterable & ~Copyable, E == S.Element, E: ~Copyable {
  struct BorrowingIterator: BorrowingIteratorProtocol & ~Copyable & ~Escapable {
    private var _testCaseGenerator: Test.Case.Generator<S, E>
    private var _iterator: S.BorrowingIterator?
    private var _testCaseIDs = [Test.Case.ID: Int]()
    private var _currentTestCases = [Test.Case]()

    @_lifetime(borrow testCaseGenerator)
    init(testCaseGenerator: borrowing Test.Case.Generator<S, E>) {
      _testCaseGenerator = copy testCaseGenerator
    }

    @_lifetime(&self)
    mutating func nextSpan(maxCount: Int) throws(S.BorrowingIterator.Failure) -> Span<Test.Case> {
      if _iterator == nil {
        _iterator = _testCaseGenerator._argumentList.sequence.makeBorrowingIterator()
      }
      let span = try _iterator!.nextSpan(maxCount: maxCount)
      _currentTestCases = []
      for i in 0 ..< span.count {
        _currentTestCases.append(_testCaseGenerator._makeTestCase(from: span[i], testCaseIDs: &_testCaseIDs))
      }
      return _currentTestCases.span
    }
  }

  @_lifetime(borrow self)
  func makeBorrowingIterator() -> BorrowingIterator {
    return BorrowingIterator(testCaseGenerator: self)
  }

  var underestimatedCount: Int {
    _argumentList.sequence.underestimatedCount
  }
}
