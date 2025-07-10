//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

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
