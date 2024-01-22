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

/// Get a swift-syntax expression initializing an instance of ``Expression``
/// from an arbitrary syntax node.
///
/// - Parameters:
///   - node: A syntax node from which to construct an instance of
///     ``Expression``.
///
/// - Returns: An expression value that initializes an instance of
///   ``Expression`` for the specified syntax node.
func createExpressionExpr(from node: any SyntaxProtocol) -> ExprSyntax {
  ".__fromSyntaxNode(\(literal: node.trimmedDescription))"
}

/// Get a swift-syntax expression initializing an instance of ``Expression``
/// from an arbitrary sequence of syntax nodes representing a binary operation.
///
/// - Parameters:
///   - lhs: The left-hand operand.
///   - operator: The operator.
///   - rhs: The right-hand operand.
///
/// - Returns: An expression value that initializes an instance of
///   ``Expression`` for the specified syntax nodes.
func createExpressionExprForBinaryOperation(_ lhs: some SyntaxProtocol, _ `operator`: some SyntaxProtocol, _ rhs: some SyntaxProtocol) -> ExprSyntax {
  let arguments = LabeledExprListSyntax {
    LabeledExprSyntax(expression: StringLiteralExprSyntax(content: lhs.trimmedDescription))
    LabeledExprSyntax(expression: StringLiteralExprSyntax(content: `operator`.trimmedDescription))
    LabeledExprSyntax(expression: StringLiteralExprSyntax(content: rhs.trimmedDescription))
  }

  return ".__fromBinaryOperation(\(arguments))"
}

/// Get a swift-syntax expression initializing an instance of ``Expression``
/// from an arbitrary sequence of syntax nodes representing a function call.
///
/// - Parameters:
///   - value: The value on which the member function is being called, if any.
///   - functionName: The name of the member function being called.
///   - arguments: The arguments to the member function.
///
/// - Returns: An expression value that initializes an instance of
///   ``Expression`` for the specified syntax nodes.
func createExpressionExprForFunctionCall(_ value: (any SyntaxProtocol)?, _ functionName: some SyntaxProtocol, _ arguments: some Sequence<Argument>) -> ExprSyntax {
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

func createExpressionExprForPropertyAccess(_ value: ExprSyntax, _ keyPath: DeclReferenceExprSyntax) -> ExprSyntax {
  let arguments = LabeledExprListSyntax {
    LabeledExprSyntax(expression: StringLiteralExprSyntax(content: value.trimmedDescription))
    LabeledExprSyntax(expression: StringLiteralExprSyntax(content: keyPath.baseName.trimmedDescription))
  }

  return ".__fromPropertyAccess(\(arguments))"
}
