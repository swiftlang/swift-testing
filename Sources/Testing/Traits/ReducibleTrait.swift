//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !hasFeature(Embedded)
/// A protocol describing traits that can be reduced into other traits of the
/// same conforming type.
@_spi(Experimental)
public protocol ReducibleTrait: Trait {
  /// Combine this trait with another instance of the same trait type.
  ///
  /// - Parameters:
  ///   - other: Another instance of this trait's type.
  ///
  /// - Returns: A single trait combining `other` and `self`. If `nil`, the two
  ///   traits were not combined.
  ///
  /// This function allows traits with duplicate or overlapping information to
  /// be reduced into a smaller set of traits. The default implementation
  /// returns `nil` and does not modify `other` or `self`.
  ///
  /// This function is called after the testing library applies recursive traits
  /// (those whose ``SuiteTrait/isRecursive`` properties have the value `true`)
  /// to child suites and test functions.
  func reduce(into other: Self) -> Self?
}
#endif
