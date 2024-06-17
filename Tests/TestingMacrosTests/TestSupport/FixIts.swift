//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing a fix-it which is expected to be included in a
/// diagnostic from a macro.
struct ExpectedFixIt {
  /// A description of what this expected fix-it performs.
  var message: String

  /// An enumeration describing a change to be performed by a fix-it.
  ///
  /// - Note: Not all changes in the real `FixIt` type are currently supported
  ///   and included in this list.
  enum Change {
    /// Replace `oldSourceCode` by `newSourceCode`.
    case replace(oldSourceCode: String, newSourceCode: String)
  }

  /// The changes that would be performed when this expected fix-it is applied.
  var changes: [Change] = []
}
