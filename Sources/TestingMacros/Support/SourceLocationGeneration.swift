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
import SwiftSyntaxMacros

/// Get an expression initializing an instance of ``SourceLocation`` from an
/// arbitrary syntax node.
///
/// - Parameters:
///   - node: The syntax node for which an instance of ``SourceLocation`` is
///     needed.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: An expression value that initializes an instance of
///   ``SourceLocation`` for `node`.
func createSourceLocationExpr(of node: some SyntaxProtocol, context: some MacroExpansionContext) -> ExprSyntax {
  if node.isProtocol((any FreestandingMacroExpansionSyntax).self) {
    // Freestanding macro expressions can just use __here()
    // directly and do not need to talk to the macro context to get source
    // location info.
    return "Testing.SourceLocation.__here()"
  }

  // Get the equivalent source location in both `#fileID` and `#filePath` modes.
  guard let fileIDSourceLoc: AbstractSourceLocation = context.location(of: node),
        let filePathSourceLoc: AbstractSourceLocation = context.location(of: node, at: .afterLeadingTrivia, filePathMode: .filePath)
  else {
    return "Testing.SourceLocation.__here()"
  }

  return "Testing.SourceLocation(fileID: \(fileIDSourceLoc.file), filePath: \(filePathSourceLoc.file), line: \(fileIDSourceLoc.line), column: \(fileIDSourceLoc.column))"
}

/// Get an expression initializing an instance of `__SourceBounds` from two
/// arbitrary syntax nodesvalues.
///
/// - Parameters:
///   - lowerBoundNode: The syntax node representing the lower bound. The start
///     of this node (after leading trivia) is used.
///   - upperBoundNode: The syntax node representing the upper bound. The end of
///     this node (before trailing trivia) is used.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: An expression value that initializes an instance of
///   `__SourceBounds`.
///
/// The resulting source bounds instance represents (approximately):
///
/// ```swift
/// lowerBoundNode.positionAfterSkippingLeadingTrivia ..< upperBoundNode.endPositionBeforeTrailingTrivia
/// ```
func createSourceBoundsExpr(from lowerBoundNode: some SyntaxProtocol, to upperBoundNode: some SyntaxProtocol, in context: some MacroExpansionContext) -> ExprSyntax {
  let lowerBoundExpr = createSourceLocationExpr(of: lowerBoundNode, context: context)
  let upperBoundExpr: ExprSyntax = if let upperBoundSourceLoc = context.location(of: upperBoundNode, at: .beforeTrailingTrivia, filePathMode: .fileID) {
    "(\(upperBoundSourceLoc.line), \(upperBoundSourceLoc.column))"
  } else {
    "(.max, .max)"
  }
  return "Testing.__SourceBounds(__uncheckedLowerBound: \(lowerBoundExpr), upperBound: \(upperBoundExpr))"
}
