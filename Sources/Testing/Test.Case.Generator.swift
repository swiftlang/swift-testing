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
    /// The underlying sequence of argument values.
    ///
    /// The sequence _must_ be iterable multiple times. Hence, initializers
    /// accept only _collections_, not sequences. The constraint here is only to
    /// `Sequence` to allow the storage of computed sequences over collections
    /// (such as `CartesianProduct` or `Zip2Sequence`) that are safe to iterate
    /// multiple times.
    private var _sequence: S

    /// A closure that maps an element from `_sequence` to a test case instance.
    ///
    /// - Parameters:
    ///   - element: The element from `_sequence`.
    ///
    /// - Returns: A test case instance that tests `element`.
    private var _mapElement: @Sendable (_ element: S.Element) -> Test.Case

    /// Initialize an instance of this type.
    ///
    /// - Parameters:
    ///   - sequence: The sequence of argument values for which test cases
    ///     should be generated.
    ///   - mapElement: A function that maps each element in `sequence` to a
    ///     corresponding instance of ``Test/Case``.
    private init(
      sequence: S,
      mapElement: @escaping @Sendable (_ element: S.Element) -> Test.Case
    ) {
      _sequence = sequence
      _mapElement = mapElement
    }

    /// Initialize an instance of this type that generates exactly one test
    /// case.
    ///
    /// - Parameters:
    ///   - testFunction: The test function called by the generated test case.
    init(
      testFunction: @escaping @Sendable () async throws -> Void
    ) where S == CollectionOfOne<Void> {
      // A beautiful hack to give us the right number of cases: iterate over a
      // collection containing a single Void value.
      self.init(sequence: CollectionOfOne(())) { _ in
        Test.Case(arguments: [], body: testFunction)
      }
    }

    /// Initialize an instance of this type that iterates over the specified
    /// collection of argument values.
    ///
    /// - Parameters:
    ///   - collection: The collection of argument values for which test cases
    ///     should be generated.
    ///   - testFunction: The test function to which each generated test case
    ///     passes an argument value from `collection`.
    init(
      arguments collection: S,
      testFunction: @escaping @Sendable (S.Element) async throws -> Void
    ) where S: Collection {
      self.init(sequence: collection) { element in
        Test.Case(arguments: [element]) {
          try await testFunction(element)
        }
      }
    }

    /// Initialize an instance of this type that iterates over the specified
    /// collections of argument values.
    ///
    /// - Parameters:
    ///   - collection1: The first collection of argument values for which test
    ///     cases should be generated.
    ///   - collection2: The second collection of argument values for which test
    ///     cases should be generated.
    ///   - testFunction: The test function to which each generated test case
    ///     passes an argument value from `collection`.
    init<C1, C2>(
      arguments collection1: C1, _ collection2: C2,
      testFunction: @escaping @Sendable (C1.Element, C2.Element) async throws -> Void
    ) where S == CartesianProduct<C1, C2> {
      self.init(sequence: cartesianProduct(collection1, collection2)) { element in
        Test.Case(arguments: [element.0, element.1]) {
          try await testFunction(element.0, element.1)
        }
      }
    }

    /// Initialize an instance of this type that iterates over the specified
    /// zipped sequence of argument values.
    ///
    /// - Parameters:
    ///   - zippedCollections: A zipped sequence of argument values for which
    ///     test cases should be generated.
    ///   - testFunction: The test function to which each generated test case
    ///     passes an argument value from `zippedCollections`.
    init<C1, C2>(
      arguments zippedCollections: Zip2Sequence<C1, C2>,
      testFunction: @escaping @Sendable ((C1.Element, C2.Element)) async throws -> Void
    ) where S == Zip2Sequence<C1, C2> {
      self.init(sequence: zippedCollections) { element in
        Test.Case(arguments: [element]) {
          try await testFunction(element)
        }
      }
    }
  }
}

// MARK: - Sequence

extension Test.Case.Generator: Sequence {
  func makeIterator() -> some IteratorProtocol<Test.Case> {
    _sequence.lazy.map(_mapElement).makeIterator()
  }

  var underestimatedCount: Int {
    _sequence.underestimatedCount
  }
}

// MARK: - TestCases

extension Test.Case.Generator: TestCases {}
