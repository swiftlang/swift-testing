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

/// Get an expression initializing an instance of ``SourceCode`` from an
/// arbitrary sequence of syntax nodes.
///
/// - Parameters:
///   - nodes: One or more syntax nodes from which to construct an instance of
///     ``SourceCode``. If an element in this sequence is `nil`, a `nil` literal
///     is passed instead of a string literal.
///
/// - Returns: An expression value that initializes an instance of
///   ``SourceCode`` for the syntax nodes in `nodes`.
func createSourceCodeExpr(from nodes: (any SyntaxProtocol)?...) -> ExprSyntax {
  let arguments = LabeledExprListSyntax {
    for node in nodes {
      if let node {
        LabeledExprSyntax(expression: StringLiteralExprSyntax(content: node.trimmedDescription))
      } else {
        LabeledExprSyntax(expression: NilLiteralExprSyntax())
      }
    }
  }

  return ".__fromComponents(\(arguments))"
}

/// Get an expression initializing an instance of ``SourceCode`` from an
/// arbitrary sequence of syntax nodes.
///
/// - Parameters:
///   - value: The value on which the member function is being called.
///   - functionName: The name of the member function being called.
///   - arguments: The arguments to the member function.
///
/// - Returns: An expression value that initializes an instance of
///   ``SourceCode`` for the specified syntax nodes.
func createSourceCodeExprForMemberFunctionCall(_ value: (some SyntaxProtocol)?, _ functionName: some SyntaxProtocol, _ arguments: some Sequence<Argument>) -> ExprSyntax {
  let arguments = LabeledExprListSyntax {
    if let value {
      LabeledExprSyntax(expression: StringLiteralExprSyntax(content: value.trimmedDescription))
    } else {
      LabeledExprSyntax(expression: NilLiteralExprSyntax())
    }
    LabeledExprSyntax(expression: StringLiteralExprSyntax(content: functionName.trimmedDescription))
    for argument in arguments {
      LabeledExprSyntax(expression: TupleExprSyntax {
        if let argumentLabel = argument.label {
          LabeledExprSyntax(expression: StringLiteralExprSyntax(content: argumentLabel.trimmedDescription))
        } else {
          LabeledExprSyntax(expression: NilLiteralExprSyntax())
        }
        LabeledExprSyntax(expression: StringLiteralExprSyntax(content: argument.expression.trimmedDescription))
      })
    }
  }

  return ".__functionCall(\(arguments))"
}
