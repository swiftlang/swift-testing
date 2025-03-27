//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if ExperimentalExitTestValueCapture
import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A type representing a value extracted from a closure's capture list.
struct CapturedValueInfo {
  /// The original instance of `ClosureCaptureSyntax` used to create this value.
  var capture: ClosureCaptureSyntax

  /// The name of the captured value.
  var name: TokenSyntax {
    let text = capture.name.textWithoutBackticks
    if text.isValidSwiftIdentifier(for: .variableName) {
      return capture.name
    }
    return .identifier("`\(text)`")
  }

  /// The expression to assign to the captured value.
  var expression: ExprSyntax

  /// The type of the captured value.
  var type: TypeSyntax

  init(_ capture: ClosureCaptureSyntax, in context: some MacroExpansionContext) {
    self.capture = capture
    self.expression = "()"
    self.type = "Swift.Void"

    // We don't support capture specifiers at this time.
    if let specifier = capture.specifier {
      context.diagnose(.specifierUnsupported(specifier, on: capture))
      return
    }

    if let initializer = capture.initializer {
      // Found an initializer clause. Extract the expression it captures.
      self.expression = initializer.value

      // Find the 'as' clause so we can determine the type of the captured value.
      guard let asExpr = (removeParentheses(from: expression) ?? expression).as(AsExprSyntax.self) else {
        context.diagnose(.typeOfCaptureIsAmbiguous(capture, initializedWith: initializer))
        return
      }

      self.type = if asExpr.questionOrExclamationMark?.tokenKind == .postfixQuestionMark {
        // If the caller us using as?, make the type optional.
        TypeSyntax(OptionalTypeSyntax(wrappedType: type.trimmed))
      } else {
        asExpr.type
      }

    } else if capture.name.tokenKind == .keyword(.self) {
      // Capturing self is special-cased if we can find the type name in the
      // enclosing scope.
      var lexicalContext = context.lexicalContext[...]
      lexicalContext = lexicalContext.drop { !$0.isProtocol((any DeclGroupSyntax).self) }
      if let typeName = context.type(ofLexicalContext: lexicalContext) {
        self.expression = "self"
        self.type = typeName
      } else {
        context.diagnose(.typeOfCaptureIsAmbiguous(capture))
      }

    } else {
      // Not enough contextual information to derive the type here.
      context.diagnose(.typeOfCaptureIsAmbiguous(capture))
    }
  }
}
#endif
