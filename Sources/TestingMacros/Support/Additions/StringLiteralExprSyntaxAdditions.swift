//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftSyntax

extension StringLiteralExprSyntax {
  /// Whether or not this string literal expression is completely empty.
  ///
  /// The value of this property is `false` even if the literal contains one or
  /// more interpolation segments whose evaluated expressions are an empty
  /// string. The value is only `true` if this string literal contains only one
  /// empty string segment.
  var isEmptyLiteral: Bool {
    guard segments.count == 1,
          case let .stringSegment(stringSegment) = segments.first,
          case let .stringSegment(text) = stringSegment.content.tokenKind
    else {
      return false
    }

    return text.isEmpty
  }
}
