//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type describing the [Cartesian product](https://en.wikipedia.org/wiki/Cartesian_product)
/// of two collections.
///
/// A Cartesian product of two sets is the ordered set containing each pair of
/// elements in those two sets. For example, if the inputs are `[1, 2, 3]`
/// and `["a", "b", "c"]`, the Cartesian product is the set
/// `[(1, "a"), (1, "b"), (1, "c"), (2, "a"), (2, "b"), ... (3, "c")]`.
///
/// This type is not part of the public interface of the testing library.
///
/// @Comment {
///   - Bug: The testing library should support variadic generics.
///     ([103416861](rdar://103416861))
/// }
public struct __CartesianProduct<S>: LazySequenceProtocol where S: LazySequenceProtocol {
  private var _sequenceGenerator: @Sendable () -> S

  fileprivate init(underestimatedCount: Int, sequenceGenerator: @escaping @Sendable () -> S) {
    self.underestimatedCount = underestimatedCount
    _sequenceGenerator = sequenceGenerator
  }

  // MARK: - Sequence

  public typealias Element = S.Element

  public func makeIterator() -> some IteratorProtocol<Element> {
    _sequenceGenerator().makeIterator()
  }

  public private(set) var underestimatedCount: Int
}

extension __CartesianProduct: Sendable where S: Sendable {}

private func _multiplyCount(_ count: inout Int, by newCount: Int) {
  let (result, overflowed) = count.multipliedReportingOverflow(by: newCount)
  count = overflowed ? .max : result
}

/// Creates the Cartesian product of two collections.
///
/// - Parameters:
///   - collection1: The first collection in the Cartesian product.
///   - collection2: The second collection in the Cartesian product.
///
/// - Returns: A sequence of tuples of type `(C1.Element, C2.Element)` derived
///   from the input collections. The sequence can be iterated multiple times.
///
/// When iterating the resulting sequence, `collection1` is iterated only once,
/// while `collection2` is iterated `collection1.count` times.
///
/// For more information on Cartesian products, see ``CartesianProduct``.
///
/// @Comment {
///   - Bug: The testing library should support variadic generics.
///     ([103416861](rdar://103416861))
/// }
public func __cartesianProduct<each C, S>(arguments collections: repeat each C, sequenceGenerator: @escaping @Sendable (repeat each C) -> S) -> __CartesianProduct<S> where repeat each C: Collection & Sendable {
  var underestimatedCount = 1
  repeat _multiplyCount(&underestimatedCount, by: (each collections).underestimatedCount)
  let sequenceGenerator: @Sendable () -> S = {
    sequenceGenerator(repeat each collections)
  }
  return __CartesianProduct(underestimatedCount: underestimatedCount, sequenceGenerator: sequenceGenerator)
}
