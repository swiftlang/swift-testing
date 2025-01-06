//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftSyntax

extension TokenSyntax {
  /// A tuple containing the text of this instance with enclosing backticks
  /// removed and whether or not they were removed.
  private var _textWithoutBackticks: (String, backticksRemoved: Bool) {
    let text = text
    if case .identifier = tokenKind, text.first == "`" && text.last == "`" && text.count >= 2 {
      return (String(text.dropFirst().dropLast()), true)
    }

    return (text, false)
  }

  /// The text of this instance with all backticks removed.
  ///
  /// - Bug: This property works around the presence of backticks in `text.`
  ///   ([swift-syntax-#1936](https://github.com/swiftlang/swift-syntax/issues/1936))
  var textWithoutBackticks: String {
    _textWithoutBackticks.0
  }

  /// The raw identifier, not including enclosing backticks, represented by this
  /// token, or `nil` if it does not represent one.
  var rawIdentifier: String? {
    let (textWithoutBackticks, backticksRemoved) = _textWithoutBackticks
    if backticksRemoved, textWithoutBackticks.contains(where: \.isWhitespace) {
      return textWithoutBackticks
    }

    // TODO: remove this mock path once the toolchain fully supports raw IDs.
    let mockPrefix = "__raw__$"
    if backticksRemoved, textWithoutBackticks.starts(with: mockPrefix) {
      return String(textWithoutBackticks.dropFirst(mockPrefix.count))
    }

    return nil
  }
}
