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
import SwiftSyntaxMacros

/// Get an expression initializing an instance of ``SourceLocation`` from an
/// arbitrary expression value.
///
/// - Parameters:
///   - expr: The expression value for which an instance of ``SourceLocation``
///     is needed.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: An expression value that initializes an instance of
///   ``SourceLocation`` for `expr`.
func createSourceLocationExpr(of expr: some SyntaxProtocol, context: some MacroExpansionContext) -> ExprSyntax {
  // Get the equivalent source location in both `#fileID` and `#filePath` modes
  guard let fileIDSourceLoc: AbstractSourceLocation = context.location(of: expr),
        let filePathSourceLoc: AbstractSourceLocation = context.location(of: expr, at: .afterLeadingTrivia, filePathMode: .filePath)
  else {
    return "Testing.SourceLocation()"
  }

  return "Testing.SourceLocation(fileID: \(fileIDSourceLoc.file), filePath: \(filePathSourceLoc.file), line: \(fileIDSourceLoc.line), column: \(fileIDSourceLoc.column))"
}
