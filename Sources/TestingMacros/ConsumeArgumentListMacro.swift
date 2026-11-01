//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftParser
public import SwiftSyntax
import SwiftSyntaxBuilder
public import SwiftSyntaxMacros

/// The implementation of the `#__consumeArgumentList()` macro when the argument
/// list conforms to `Copyable`.
///
/// This type is used to implement the `#__consumeArgumentList()` macro. Do not
/// use it directly.
public struct ConsumeCopyableArgumentListMacro: ExpressionMacro, Sendable {
  public static func expansion(
    of macro: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    let arguments = Array(macro.arguments)
    let expr = arguments[0].expression

    // No additional processing is required as this expression's type meets our
    // requirements.

    return expr
  }
}

/// The implementation of the `#__consumeArgumentList()` macro when the argument
/// list does _not_ conform to `Copyable`.
///
/// This type is used to implement the `#__consumeArgumentList()` macro. Do not
/// use it directly.
public struct ConsumeMoveOnlyArgumentListMacro: ExpressionMacro, Sendable {
  public static func expansion(
    of macro: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    let arguments = Array(macro.arguments)
    let expr = arguments[0].expression
    let typeNameExpr = arguments[1].expression.cast(StringLiteralExprSyntax.self)

    // Diagnose that the `consuming` specifier is invalid.
    let functionParameter = FunctionParameterSyntax(
      firstName: .identifier("_"),
      type: "\(raw: typeNameExpr.representedLiteralValue!)" as TypeSyntax
    )
    let attribute = AttributeSyntax("Test" as TypeSyntax)
    context.diagnose(.specifierNotSupported(.keyword(.consuming), on: functionParameter, isMoveOnly: true, whenUsing: attribute))

    return expr
  }
}
