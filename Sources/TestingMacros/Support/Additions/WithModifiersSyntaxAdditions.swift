//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftIfConfig
import SwiftSyntax
import SwiftSyntaxMacros

extension WithModifiersSyntax {
  /// The `open` modifier, if any, applied to this declaration.
  var openModifier: DeclModifierSyntax? {
    modifiers.first { $0.name.tokenKind == .keyword(.open) }
  }

  /// The `override` modifier, if any, applied to this declaration.
  var overrideModifier: DeclModifierSyntax? {
    modifiers.first { $0.name.tokenKind == .keyword(.override) }
  }

  /// Check whether or not this declaration is an inheritable test or suite
  /// declaration.
  ///
  /// - Parameters:
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: Whether or not this declaration should be inherited by
  ///   subclasses of this declaration (if it is a class) or subclasses of its
  ///   containing declaration (if it is a function).
  func isInheritableTestDeclaration(in context: some MacroExpansionContext) -> Bool {
    var isInheritable = self.openModifier != nil
    if !isInheritable,
       self.is(FunctionDeclSyntax.self),
       let containingTypeDecl = context.lexicalContext.first?.asProtocol((any WithModifiersSyntax).self) {
      isInheritable = containingTypeDecl.openModifier != nil
    }
    if isInheritable && !isTestInheritanceEnabled(in: context) {
      // Test inheritance is disabled.
      isInheritable = false
    }
    return isInheritable
  }
}

/// Check whether the experimental test inheritance feature is enabled.
///
/// - Parameters:
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: Whether or not the feature is enabled.
func isTestInheritanceEnabled(in context: some MacroExpansionContext) -> Bool {
  if let buildConfiguration = context.buildConfiguration,
     let isInheritanceEnabled = try? buildConfiguration.isCustomConditionSet(name: "SWIFT_TESTING_EXPERIMENTAL_TEST_INHERITANCE_ENABLED") {
    return isInheritanceEnabled
  }
  return false
}
