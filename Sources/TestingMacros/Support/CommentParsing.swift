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
import SwiftSyntaxBuilder

/// Find a common whitespace prefix among all lines in a string and trim it.
///
/// - Parameters:
///   - string: The string to trim.
///
/// - Returns: A copy of `string` with leading whitespace trimmed, or `string`
///   verbatim if all lines do not share a common whitespace prefix.
private func _trimCommonLeadingWhitespaceFromLines(in string: String) -> String {
  var lines = string.split(whereSeparator: \.isNewline)

  var firstLine = lines.first
  while let firstCharacter = firstLine?.first, firstCharacter.isWhitespace {
    defer {
      firstLine?.removeFirst()
    }
    if lines.lazy.map(\.first).allSatisfy({ $0 == firstCharacter }) {
      lines = lines.map { $0.dropFirst() }
    }
  }

  return lines.joined(separator: "\n")
}

/// Trim an instance of `Trivia` and return its pieces after the last
/// double-newline sequence (if one is present.)
///
/// - Parameters:
///   - trivia: The trivia to inspect.
///
/// - Returns: A subset of the pieces in `trivia` following the last
///   double-newline sequence (ignoring other whitespace.) All whitespace trivia
///   pieces are removed from the result.
///
/// This function allows ``createCommentTraitExprs(for:)`` to ignore unrelated
/// comments that are included in the leading trivia of some syntax node. For
/// example:
///
/// ```swift
/// /* Not relevant */
///
/// /* Relevant */
/// #expect(...)
/// ```
///
/// `/* Not relevant */` is not included in the result, while `/* Relevant */`
/// is included.
private func _trimTriviaToLastDoubleNewline(_ trivia: Trivia) -> some Sequence<TriviaPiece> {
  var result = [TriviaPiece]()

  // Walk the trivia pieces backwards until we hit a double-newline. We'll take
  // this loop as an opportunity to do some additional cleanup as well.
  for triviaPiece in trivia.pieces.reversed() {
    // Check if we've hit a double-newline.
    if let newlineCount = triviaPiece.newlineCount {
      if let lastTriviaPiece = result.last, lastTriviaPiece.isNewline {
        break
      } else if newlineCount > 1 {
        break
      }
    }

    if triviaPiece.isWhitespace && !triviaPiece.isNewline {
      // Tack whitespace onto the preceding trivia piece (which is next in
      // source because we're iterating backwards) if it's a comment. That way,
      // indentation is consistent among all lines in the comment. After this
      // loop concludes, we'll strip off that whitespace.
      //
      // For example:
      // ___/* x
      // ___   y */
      let newLastPiece: TriviaPiece?
      switch result.last {
      case let .some(.docBlockComment(comment)):
        newLastPiece = .docBlockComment("\(triviaPiece)\(comment)")
      case let .some(.blockComment(comment)):
        newLastPiece = .blockComment("\(triviaPiece)\(comment)")
      default:
        newLastPiece = nil
      }
      if let newLastPiece {
        result[result.count - 1] = newLastPiece
      }
    } else {
      // Preserve newlines and non-whitespace trivia pieces.
      result.append(triviaPiece)
    }
  }

  // Trim common leading whitespace from block comments. Remember that we added
  // leading whitespace above, and that whitespace is what we should be trimming
  // in this loop.
  result = result.map { triviaPiece in
    switch triviaPiece {
    case let .docBlockComment(comment):
      return .docBlockComment(_trimCommonLeadingWhitespaceFromLines(in: comment))
    case let .blockComment(comment):
      return .blockComment(_trimCommonLeadingWhitespaceFromLines(in: comment))
    default:
      return triviaPiece
    }
  }

  return result.reversed().lazy.filter { !$0.isWhitespace }
}

/// Create an expression that contains an array of ``Comment`` instances based
/// on the code comments present on the specified node.
///
/// - Parameters:
///   - node: The node which may contain code comments.
///
/// - Returns: An array of expressions producing ``Comment`` instances. If
///   `node` has no code comments, an empty array is returned.
func createCommentTraitExprs(for node: some SyntaxProtocol) -> [ExprSyntax] {
  _trimTriviaToLastDoubleNewline(node.leadingTrivia).compactMap { triviaPiece in
    switch triviaPiece {
    case .lineComment(let comment):
      ".__line(\(literal: comment))"
    case .blockComment(let comment):
      ".__block(\(literal: comment))"
    case .docLineComment(let comment):
      ".__documentationLine(\(literal: comment))"
    case .docBlockComment(let comment):
      ".__documentationBlock(\(literal: comment))"
    default:
      nil
    }
  }
}
