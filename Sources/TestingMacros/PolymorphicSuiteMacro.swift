//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftDiagnostics
public import SwiftSyntax
import SwiftSyntaxBuilder
public import SwiftSyntaxMacros

/// A type describing the expansion of the `@polymorphic` attribute macro.
///
/// This type is used to implement the `@polymorphic` attribute macro. Do not
/// use it directly.
public struct PolymorphicSuiteMacro: ExtensionMacro, Sendable {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard _diagnoseIssues(with: declaration, polymorphicAttribute: node, in: context) else {
      return []
    }

    let extensionDecl: DeclSyntax = """
    extension \(type.trimmed) : Testing.__PolymorphicSuite {}
    """
    return [extensionDecl.cast(ExtensionDeclSyntax.self)]
  }
  
  /// Diagnose issues with the `@polymorphic` attribute.
  ///
  /// - Parameters:
  ///   - decl: The declaration to diagnose.
  ///   - polymorphicAttribute: The `@polymorphic` attribute applied to `decl`.
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: Whether or not macro expansion should continue (i.e. stopping
  ///   if a fatal error was diagnosed.)
  private static func _diagnoseIssues(
    with decl: some DeclSyntaxProtocol,
    polymorphicAttribute: AttributeSyntax,
    in context: some MacroExpansionContext
  ) -> Bool {
    var diagnostics = [DiagnosticMessage]()
    defer {
      context.diagnose(diagnostics)
    }

    // The @polymorphic attribute is only supported on class and actor
    // declarations. (Note that extension macros cannot be applied to extension
    // declarations, so we don't need to think about them).
    guard decl.kind == .classDecl || decl.kind == .actorDecl else {
      diagnostics.append(.attributeNotSupported(polymorphicAttribute, on: decl))
      return false
    }

    // The @polymorphic attribute must be used with @Suite because @Suite is the
    // one that emits the test content record containing the isPolymorphic flag.
    if let attributedDecl = decl.asProtocol((any WithAttributesSyntax).self),
       attributedDecl.attributes(named: "Suite").isEmpty {
      diagnostics.append(.attributeNotSupported(polymorphicAttribute, withoutAttribute: "@Suite", on: decl))
    }

    if let modifiedDecl = decl.asProtocol((any WithModifiersSyntax).self) {
      let finalModifier = modifiedDecl.modifiers.first { $0.name.tokenKind == .keyword(.final) }
      if let finalModifier {
        diagnostics.append(.attributeHasNoEffect(polymorphicAttribute, becauseOf: finalModifier, on: decl))
      }
    }

    return !diagnostics.lazy.map(\.severity).contains(.error)
  }
}
