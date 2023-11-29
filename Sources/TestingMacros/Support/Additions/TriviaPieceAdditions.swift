//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if swift(>=5.11)
import SwiftSyntax
#else
public import SwiftSyntax
#endif

extension TriviaPiece {
  /// The number of newline characters represented by this trivia piece.
  ///
  /// If this trivia piece contains text (such as a comment), the value of this
  /// property is `nil`.
  var newlineCount: Int? {
    switch self {
    case let .carriageReturns(count),
      let .carriageReturnLineFeeds(count), let .formfeeds(count),
      let .newlines(count), let .verticalTabs(count):
      return count
    default:
      return nil
    }
  }
}
