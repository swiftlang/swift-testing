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

    // Potentially get the name of the type comprising the current lexical
    // context (i.e. whatever `Self` is.)
    lazy var lexicalContext = context.lexicalContext
    lazy var typeNameOfLexicalContext = {
      let lexicalContext = lexicalContext.drop { !$0.isProtocol((any DeclGroupSyntax).self) }
      return context.type(ofLexicalContext: lexicalContext)
    }()

    if let initializer = capture.initializer {
      // Found an initializer clause. Extract the expression it captures.
      self.expression = removeParentheses(from: initializer.value) ?? initializer.value

      // Find the 'as' clause so we can determine the type of the captured value.
      if let asExpr = self.expression.as(AsExprSyntax.self) {
        self.type = if asExpr.questionOrExclamationMark?.tokenKind == .postfixQuestionMark {
          // If the caller is using as?, make the type optional.
          TypeSyntax(OptionalTypeSyntax(wrappedType: asExpr.type.trimmed))
        } else {
          asExpr.type
        }
      } else if let selfExpr = self.expression.as(DeclReferenceExprSyntax.self),
                selfExpr.baseName.tokenKind == .keyword(.self),
                selfExpr.argumentNames == nil,
                let typeNameOfLexicalContext {
        // Copying self.
        self.type = typeNameOfLexicalContext
      } else {
        // Handle literals. Any other types are ambiguous.
        switch self.expression.kind {
        case .integerLiteralExpr:
          self.type = TypeSyntax(IdentifierTypeSyntax(name: .identifier("IntegerLiteralType")))
        case .floatLiteralExpr:
          self.type = TypeSyntax(IdentifierTypeSyntax(name: .identifier("FloatLiteralType")))
        case .booleanLiteralExpr:
          self.type = TypeSyntax(IdentifierTypeSyntax(name: .identifier("BooleanLiteralType")))
        case .stringLiteralExpr, .simpleStringLiteralExpr:
          self.type = TypeSyntax(IdentifierTypeSyntax(name: .identifier("StringLiteralType")))
        default:
          context.diagnose(.typeOfCaptureIsAmbiguous(capture, initializedWith: initializer))
        }
      }

    } else if capture.name.tokenKind == .keyword(.self),
              let typeNameOfLexicalContext {
      // Capturing self.
      self.expression = "self"
      self.type = typeNameOfLexicalContext
    } else if let parameterType = Self._findTypeOfParameter(named: capture.name, in: lexicalContext) {
      self.expression = ExprSyntax(DeclReferenceExprSyntax(baseName: capture.name.trimmed))
      self.type = parameterType
    } else {
      // Not enough contextual information to derive the type here.
      context.diagnose(.typeOfCaptureIsAmbiguous(capture))
    }
  }

  /// Find a function or closure parameter in the given lexical context with a
  /// given name and return its type.
  ///
  /// - Parameters:
  /// 	- parameterName: The name of the parameter of interest.
  ///   - lexicalContext: The lexical context to examine.
  ///
  /// - Returns: The Swift type of first parameter found whose name matches, or
  /// 	`nil` if none was found. The lexical context is searched in the order
  ///   provided which, by default, starts with the innermost scope.
  private static func _findTypeOfParameter(named parameterName: TokenSyntax, in lexicalContext: [Syntax]) -> TypeSyntax? {
    for lexicalContext in lexicalContext {
      var parameterType: TypeSyntax?
      if let functionDecl = lexicalContext.as(FunctionDeclSyntax.self) {
        parameterType = functionDecl.signature.parameterClause.parameters
          .first { ($0.secondName ?? $0.firstName).tokenKind == parameterName.tokenKind }
          .map(\.type)
      } else if let closureExpr = lexicalContext.as(ClosureExprSyntax.self) {
        if case let .parameterClause(parameterClause) = closureExpr.signature?.parameterClause {
          parameterType = parameterClause.parameters
            .first { ($0.secondName ?? $0.firstName).tokenKind == parameterName.tokenKind }
            .flatMap(\.type)
        }
      } else if lexicalContext.is(DeclSyntax.self) {
        // If we've reached any other enclosing declaration, then any parameters
        // beyond it won't be capturable and thus it isn't possible to infer
        // types from them (any capture of `x`, for instance, must refer to some
        // more-local variable with that name, not to a parameter named `x`.)
        return nil
      }

      if let parameterType {
        return parameterType
      }
    }

    return nil
  }
}
