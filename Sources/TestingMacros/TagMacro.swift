//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

public import SwiftSyntax
public import SwiftSyntaxMacros

/// A type describing the expansion of the `@Tag` attribute macro.
///
/// This type is used to implement the `@Tag` attribute macro. Do not use it
/// directly.
public struct TagMacro: AccessorMacro, Sendable {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
      context.diagnose(.attributeNotSupported(node, on: declaration))
      return []
    }
    guard variableDecl.modifiers.map(\.name.tokenKind).contains(.keyword(.static)) else {
      context.diagnose(.attributeNotSupported(node, on: declaration))
      return []
    }
    guard variableDecl.bindings.count == 1 else {
      context.diagnose(.attributeNotSupported(node, on: declaration))
      return []
    }
    guard let variableName = variableDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
      context.diagnose(.attributeNotSupported(node, on: declaration))
      return []
    }

    return [
      #"""
      get {
        Testing.Tag.__fromStaticMember(of: self, \#(literal: variableName.textWithoutBackticks))
      }
      """#
    ]
  }
}

public struct FnordMacro: ExpressionMacro, Sendable {
  public static func expansion(
    of macro: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    context.debug(context.lexicalContext, node: macro)
    return "\(literal: "fnord")"
  }
}