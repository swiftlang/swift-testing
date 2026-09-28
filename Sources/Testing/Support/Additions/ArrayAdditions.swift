//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

extension Array {
  /// Initialize an array from a single optional value.
  ///
  /// - Parameters:
  ///   - optionalValue: The value to place in the array.
  ///
  /// If `optionalValue` is not `nil`, it is unwrapped and the resulting array
  /// contains a single element equal to its value. If `optionalValue` is `nil`,
  /// the resulting array is empty.
  init(_ optionalValue: Element?) {
    self = optionalValue.map { [$0] } ?? []
  }

  /// Perform a binary search on this array looking for an element that matches
  /// the given predicate function.
  ///
  /// - Parameters:
  ///   - predicate: A predicate function to call. Elements from this array are
  ///     passed to it, and it returns the relative orderings of the desired
  ///     element and those elements.
  ///
  /// - Returns: The first element found that matches `predicate`, or `nil` if
  ///   no matching element is found.
  ///
  /// - Throws: Whatever error is thrown by `predicate`.
  ///
  /// - Precondition: The array _must_ already be sorted according to
  ///   `predicate`. If it is not sorted, the result is undefined.
  ///
  /// The result of `predicate` should reflect the relative ordering of the
  /// desired element and the element passed to `predicate`:
  ///
  /// | Relative Ordering | Result |
  /// |-|-:|
  /// | `desired < $0` | `< 0` |
  /// | `desired == $0` | `0` |
  /// | `desired > $0` | `> 0` |
  ///
  /// The implementation of this function is borrowed (almost) verbatim from
  /// [`partitioningIndex(where:)`](https://github.com/apple/swift-algorithms/blob/5b7143f8e291dee0e14c118fd0212487f0b37af5/Sources/Algorithms/Partition.swift#L229)
  /// in the swift-collections package.
  func binarySearch<E>(_ predicate: (borrowing Element) throws(E) -> Int) throws(E) -> Element? {
    var n = count
    var l = startIndex

    while n > 0 {
      let half = n / 2
      let mid = index(l, offsetBy: half)
      if try predicate(self[mid]) <= 0 {
        n = half
      } else {
        l = index(after: mid)
        n -= half + 1
      }
    }

    if l < endIndex, case let element = self[l], try predicate(element) == 0 {
      return element
    }
    return nil
  }
}

/// Get the number of elements in a parameter pack.
///
/// - Parameters:
///   - pack: The parameter pack.
///
/// - Returns: The number of elements in `pack`.
///
/// - Complexity: O(_n_) where _n_ is the number of elements in `pack`. The
///   compiler may be able to optimize this operation when the types of `pack`
///   are statically known.
func parameterPackCount<each T>(_ pack: repeat each T) -> Int {
  var result = 0
  for _ in repeat each pack {
    result += 1
  }
  return result
}
