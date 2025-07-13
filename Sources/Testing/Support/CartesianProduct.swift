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
struct CartesianProduct<C1, C2>: LazySequenceProtocol where C1: Collection, C2: Collection {
  fileprivate var collection1: C1
  fileprivate var collection2: C2

  // MARK: - Sequence

  typealias Element = (C1.Element, C2.Element)

  func makeIterator() -> some IteratorProtocol<Element> {
    collection1.lazy.flatMap { e1 in
      collection2.lazy.map { e2 in
        (e1, e2)
      }
    }.makeIterator()
  }

  var underestimatedCount: Int {
    let (result, overflowed) = collection1.underestimatedCount
      .multipliedReportingOverflow(by: collection2.underestimatedCount)
    if overflowed {
      return .max
    }
    return result
  }
}

extension CartesianProduct: Sendable where C1: Sendable, C2: Sendable {}

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
func cartesianProduct<C1, C2>(_ collection1: C1, _ collection2: C2) -> CartesianProduct<C1, C2> where C1: Collection, C2: Collection {
  CartesianProduct(collection1: collection1, collection2: collection2)
}
