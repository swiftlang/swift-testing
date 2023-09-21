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
