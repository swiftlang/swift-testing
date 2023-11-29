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

/// Get an expression initializing an instance of ``SourceCode`` from an
/// arbitrary syntax node.
///
/// - Parameters:
///   - node: A syntax node from which to construct an instance of
///     ``SourceCode``.
///
/// - Returns: An expression value that initializes an instance of
///   ``SourceCode`` for the specified syntax node.
func createSourceCodeExpr(from node: any SyntaxProtocol) -> ExprSyntax {
  ".__fromSyntaxNode(\(literal: node.trimmedDescription))"
}

/// Get an expression initializing an instance of ``SourceCode`` from an
/// arbitrary sequence of syntax nodes representing a binary operation.
///
/// - Parameters:
///   - lhs: The left-hand operand.
///   - operator: The operator.
///   - rhs: The right-hand operand.
///
/// - Returns: An expression value that initializes an instance of
///   ``SourceCode`` for the specified syntax nodes.
func createSourceCodeExprForBinaryOperation(_ lhs: some SyntaxProtocol, _ `operator`: some SyntaxProtocol, _ rhs: some SyntaxProtocol) -> ExprSyntax {
  let arguments = LabeledExprListSyntax {
    LabeledExprSyntax(expression: StringLiteralExprSyntax(content: lhs.trimmedDescription))
    LabeledExprSyntax(expression: StringLiteralExprSyntax(content: `operator`.trimmedDescription))
    LabeledExprSyntax(expression: StringLiteralExprSyntax(content: rhs.trimmedDescription))
  }

  return ".__fromBinaryOperation(\(arguments))"
}

/// Get an expression initializing an instance of ``SourceCode`` from an
/// arbitrary sequence of syntax nodes representing a function call.
///
/// - Parameters:
///   - value: The value on which the member function is being called, if any.
///   - functionName: The name of the member function being called.
///   - arguments: The arguments to the member function.
///
/// - Returns: An expression value that initializes an instance of
///   ``SourceCode`` for the specified syntax nodes.
func createSourceCodeExprForFunctionCall(_ value: (some SyntaxProtocol)?, _ functionName: some SyntaxProtocol, _ arguments: some Sequence<Argument>) -> ExprSyntax {
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
