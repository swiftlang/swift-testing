//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A type representing a value extracted from a closure's capture list.
struct CapturedValue {
  /// The original instance of `ClosureCaptureSyntax` used to create this value.
  var capture: ClosureCaptureSyntax

  /// The name of the captured value.
  var name: TokenSyntax {
    capture.name
  }

  /// The expression to assign to the captured value.
  var expression: ExprSyntax

  /// The type of the captured value.
  var type: TypeSyntax

  init(_ capture: ClosureCaptureSyntax, in context: some MacroExpansionContext) {
    self.capture = capture
    self.expression = "()"
    self.type = "Swift.Void"

    // Find the initializer clause and extract the expression it captures.
    guard let initializer = capture.initializer else {
      context.diagnose(DiagnosticMessage(syntax: Syntax(capture), message: "[ENG] '\(capture.trimmed)' must specify a type using 'as T'! (no init)", severity: .error))
      return
    }
    self.expression = initializer.value

    // Find the 'as' clause so we can determine the type of the captured value.
    guard let asExpr = (removeParentheses(from: expression) ?? expression).as(AsExprSyntax.self) else {
      context.diagnose(DiagnosticMessage(syntax: Syntax(capture), message: "[ENG] '\(capture.trimmed)' must specify a type using 'as T'! (no as expr)", severity: .error))
      return
    }

    self.type = if asExpr.questionOrExclamationMark?.tokenKind == .postfixQuestionMark {
      // If the caller us using as?, make the type optional.
      TypeSyntax(OptionalTypeSyntax(wrappedType: type.trimmed))
    } else {
      asExpr.type
    }
  }
}
