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
#if compiler(>=5.11)
import SwiftSyntax
import SwiftSyntaxMacros
#else
public import SwiftSyntax
public import SwiftSyntaxMacros
#endif

extension AttributeInfo {
  /// Diagnose issues with the traits in a parsed attribute.
  ///
  /// - Parameters:
  ///   - context: The macro context in which the expression is being parsed.
  func diagnoseIssuesWithTraits(in context: some MacroExpansionContext) {
    for traitExpr in traits {
      if let functionCallExpr = traitExpr.as(FunctionCallExprSyntax.self),
         let calledExpr = functionCallExpr.calledExpression.as(MemberAccessExprSyntax.self) {
        // Check for .tags() traits.
        switch calledExpr.tokens(viewMode: .fixedUp).map(\.textWithoutBackticks).joined() {
        case ".tags", "Tag.List.tags", "Testing.Tag.List.tags":
          _diagnoseIssuesWithTagsTrait(functionCallExpr, addedTo: self, in: context)
        case ".bug", "Bug.bug", "Testing.Bug.bug":
          _diagnoseIssuesWithBugTrait(functionCallExpr, addedTo: self, in: context)
        default:
          // This is not a trait we can parse.
          break
        }
      } else if let memberAccessExpr = traitExpr.as(MemberAccessExprSyntax.self) {
        switch memberAccessExpr.tokens(viewMode: .fixedUp).map(\.textWithoutBackticks).joined() {
        case ".serialized", "SerializationTrait.serialized", "Testing.SerializationTrait.serialized":
          _diagnoseIssuesWithSerializedTrait(memberAccessExpr, addedTo: self, in: context)
        default:
          // This is not a trait we can parse.
          break
        }
      }
    }
  }
}

/// Diagnose issues with a `.tags()` trait in a parsed attribute.
///
/// - Parameters:
///   - traitExpr: The `.tags()` expression.
///   - attribute: The `@Test` or `@Suite` attribute.
///   - context: The macro context in which the expression is being parsed.
private func _diagnoseIssuesWithTagsTrait(_ traitExpr: FunctionCallExprSyntax, addedTo attributeInfo: AttributeInfo, in context: some MacroExpansionContext) {
  // Find tags that are in an unsupported format (only .member and "literal"
  // are allowed.)
  for tagExpr in traitExpr.arguments.lazy.map(\.expression) {
    if tagExpr.is(StringLiteralExprSyntax.self) {
      // String literals are supported tags.
    } else if let tagExpr = tagExpr.as(MemberAccessExprSyntax.self) {
      let joinedTokens = tagExpr.tokens(viewMode: .fixedUp).map(\.textWithoutBackticks).joined()
      if joinedTokens.hasPrefix(".") || joinedTokens.hasPrefix("Tag.") || joinedTokens.hasPrefix("Testing.Tag.") {
        // These prefixes are all allowed as they specify a member access
        // into the Tag type.
      } else {
        context.diagnose(.tagExprNotSupported(tagExpr, in: attributeInfo.attribute))
        continue
      }

      // Walk all base expressions and make sure they are exclusively member
      // access expressions.
      func checkForValidDeclReferenceExpr(_ declReferenceExpr: DeclReferenceExprSyntax) {
        // This is the name of a type or symbol. If there are argument names
        // (unexpected in this context), it's a function reference and is
        // unsupported.
        if declReferenceExpr.argumentNames != nil {
          context.diagnose(.tagExprNotSupported(tagExpr, in: attributeInfo.attribute))
        }
      }
      func checkForValidBaseExpr(_ baseExpr: ExprSyntax) {
        if let baseExpr = baseExpr.as(MemberAccessExprSyntax.self) {
          checkForValidDeclReferenceExpr(baseExpr.declName)
          if let baseBaseExpr = baseExpr.base {
            checkForValidBaseExpr(baseBaseExpr)
          }
        } else if let baseExpr = baseExpr.as(DeclReferenceExprSyntax.self) {
          checkForValidDeclReferenceExpr(baseExpr)
        } else {
          // The base expression was some other kind of expression and is
          // not supported.
          context.diagnose(.tagExprNotSupported(tagExpr, in: attributeInfo.attribute))
        }
      }
      if let baseExpr = tagExpr.base {
        checkForValidBaseExpr(baseExpr)
      }
    } else {
      // This tag is not of a supported expression type.
      context.diagnose(.tagExprNotSupported(tagExpr, in: attributeInfo.attribute))
    }
  }
}

/// Diagnose issues with a `.bug()` trait in a parsed attribute.
///
/// - Parameters:
///   - traitExpr: The `.bug()` expression.
///   - attribute: The `@Test` or `@Suite` attribute.
///   - context: The macro context in which the expression is being parsed.
private func _diagnoseIssuesWithBugTrait(_ traitExpr: FunctionCallExprSyntax, addedTo attributeInfo: AttributeInfo, in context: some MacroExpansionContext) {
  // If the firstargument to the .bug() trait has no label and its value is a
  // string literal, check that it can be parsed the way we expect.
  guard let urlArg = traitExpr.arguments.first, urlArg.label == nil,
        let stringLiteralExpr = urlArg.expression.as(StringLiteralExprSyntax.self),
        let urlString = stringLiteralExpr.representedLiteralValue else {
    return
  }

  // We could use libcurl, libxml, or Windows' InternetCrackUrlW() to actually
  // parse the string and ensure it is a valid URL, however we could get
  // different results on different platforms. See the branch
  // jgrynspan/type-check-bug-identifiers-with-libcurl for an implementation.
  // Instead, we apply a very basic sniff test above. We intentionally don't
  // use a regular expression here.

  let isURLStringValid = urlString.allSatisfy(\.isASCII)
    && !urlString.contains(where: \.isWhitespace)
    && urlString.contains(":")
  if !isURLStringValid {
    context.diagnose(.urlExprNotValid(stringLiteralExpr, in: traitExpr, in: attributeInfo.attribute))
  }
}

/// Diagnose issues with a `.bug()` trait in a parsed attribute.
///
/// - Parameters:
///   - traitExpr: The `.serialized` expression.
///   - attribute: The `@Test` or `@Suite` attribute.
///   - context: The macro context in which the expression is being parsed.
private func _diagnoseIssuesWithSerializedTrait(_ traitExpr: MemberAccessExprSyntax, addedTo attributeInfo: AttributeInfo, in context: some MacroExpansionContext) {
  guard attributeInfo.attribute.attributeName.isNamed("Test", inModuleNamed: "Testing") else {
    // We aren't diagnosing any issues on suites.
    return
  }

  let hasArguments = attributeInfo.otherArguments.lazy
    .compactMap(\.label?.textWithoutBackticks)
    .contains("arguments")
  if !hasArguments {
    // Serializing a non-parameterized test function has no effect.
    context.diagnose(.traitHasNoEffect(traitExpr, in: attributeInfo.attribute))
  }
}

// MARK: -

/// Diagnose issues with a synthesized suite (one without an `@Suite` attribute)
/// containing a declaration.
///
/// - Parameters:
///   - lexicalContext: The single lexical context to inspect.
///   - decl: The declaration to inspect.
///   - attribute: The `@Test` or `@Suite` attribute applied to `decl`.
///
/// - Returns: An array of zero or more diagnostic messages related to the
///   lexical context containing `decl`.
///
/// This function is also used by ``SuiteDeclarationMacro`` for a number of its
/// own diagnostics. The implementation substitutes different diagnostic
/// messages when `suiteDecl` and `decl` are the same syntax node on the
/// assumption that a suite is self-diagnosing.
func diagnoseIssuesWithLexicalContext(
  _ lexicalContext: some SyntaxProtocol,
  containing decl: some DeclSyntaxProtocol,
  attribute: AttributeSyntax
) -> [DiagnosticMessage] {
  var diagnostics = [DiagnosticMessage]()

  // Functions, closures, etc. are not supported as enclosing lexical contexts.
  guard let lexicalContext = lexicalContext.asProtocol((any DeclGroupSyntax).self) else {
    if Syntax(lexicalContext) == Syntax(decl) {
      diagnostics.append(.attributeNotSupported(attribute, on: lexicalContext))
    } else {
      diagnostics.append(.containingNodeUnsupported(lexicalContext, whenUsing: attribute, on: decl))
    }
    return diagnostics
  }

  // Generic suites are not supported.
  if let genericClause = lexicalContext.asProtocol((any WithGenericParametersSyntax).self)?.genericParameterClause {
    diagnostics.append(.genericDeclarationNotSupported(decl, whenUsing: attribute, becauseOf: genericClause, on: lexicalContext))
  } else if let whereClause = lexicalContext.genericWhereClause {
    diagnostics.append(.genericDeclarationNotSupported(decl, whenUsing: attribute, becauseOf: whereClause, on: lexicalContext))
  } else if [.arrayType, .dictionaryType, .optionalType, .implicitlyUnwrappedOptionalType].contains(lexicalContext.type.kind) {
    // These types are all syntactic sugar over generic types (Array<T>,
    // Dictionary<T>, and Optional<T>) and are just as unsupported. T! is
    // unsupported in this position, but it's still forbidden so don't even try!
    diagnostics.append(.genericDeclarationNotSupported(decl, whenUsing: attribute, becauseOf: lexicalContext.type, on: lexicalContext))
  }

  // Suites that are classes must be final.
  if let classDecl = lexicalContext.as(ClassDeclSyntax.self) {
    if !classDecl.modifiers.lazy.map(\.name.tokenKind).contains(.keyword(.final)) {
      if Syntax(classDecl) == Syntax(decl) {
        diagnostics.append(.nonFinalClassNotSupported(classDecl, whenUsing: attribute))
      } else {
        diagnostics.append(.containingNodeUnsupported(classDecl, whenUsing: attribute, on: decl))
      }
    }
  }

  // Suites cannot be protocols (there's nowhere to put most of the
  // declarations we generate.)
  if let protocolDecl = lexicalContext.as(ProtocolDeclSyntax.self) {
    if Syntax(protocolDecl) == Syntax(decl) {
      diagnostics.append(.attributeNotSupported(attribute, on: protocolDecl))
    } else {
      diagnostics.append(.containingNodeUnsupported(protocolDecl, whenUsing: attribute, on: decl))
    }
  }

  // Check other attributes on the declaration. Note that it should be
  // impossible to reach this point if the declaration can't have attributes.
  if let attributedDecl = lexicalContext.asProtocol((any WithAttributesSyntax).self) {
    // Availability is not supported on suites (we need semantic availability
    // to correctly understand the availability of a suite.)
    let availabilityAttributes = attributedDecl.availabilityAttributes
    if !availabilityAttributes.isEmpty {
      // Diagnose all @available attributes.
      for availabilityAttribute in availabilityAttributes {
        diagnostics.append(.availabilityAttributeNotSupported(availabilityAttribute, on: decl, whenUsing: attribute))
      }
    } else if let noasyncAttribute = attributedDecl.noasyncAttribute {
      // No @available attributes, but we do have an @_unavailableFromAsync
      // attribute and we still need to diagnose that.
      diagnostics.append(.availabilityAttributeNotSupported(noasyncAttribute, on: decl, whenUsing: attribute))
    }
  }

  return diagnostics
}

/// Diagnose issues with the lexical context containing a declaration.
///
/// - Parameters:
///   - lexicalContext: The lexical context to inspect.
///   - decl: The declaration to inspect.
///   - attribute: The `@Test` or `@Suite` attribute applied to `decl`.
///
/// - Returns: An array of zero or more diagnostic messages related to the
///   lexical context containing `decl`.
func diagnoseIssuesWithLexicalContext(
  _ lexicalContext: [Syntax],
  containing decl: some DeclSyntaxProtocol,
  attribute: AttributeSyntax
) -> [DiagnosticMessage] {
  lexicalContext.lazy
    .map { diagnoseIssuesWithLexicalContext($0, containing: decl, attribute: attribute) }
    .reduce(into: [], +=)
}

/// Create a declaration that prevents compilation if it is generic.
///
/// - Parameters:
///   - decl: The declaration that should not be generic.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: A declaration that will fail to compile if `decl` is generic. The
///   result declares a static member that should be added to the type
///   containing `decl`. If `decl` is known not to be contained within a type
///   extension, the result is `nil`.
///
/// This function disables the use of tests and suites inside extensions to
/// generic types by adding a static property declaration (which generic types
/// do not support.) This produces a compile-time error (not the perfect
/// diagnostic to emit, but better than building successfully and failing
/// silently at runtime.) ([126018850](rdar://126018850))
func makeGenericGuardDecl(
  guardingAgainst decl: some DeclSyntaxProtocol,
  in context: some MacroExpansionContext
) -> DeclSyntax? {
  guard context.lexicalContext.lazy.map(\.kind).contains(.extensionDecl) else {
    // Don't bother emitting a member if the declaration is not in an extension
    // because we'll already be able to emit a better error.
    return nil
  }

  let genericGuardName = if let functionDecl = decl.as(FunctionDeclSyntax.self) {
    context.makeUniqueName(thunking: functionDecl)
  } else {
    context.makeUniqueName("")
  }
  return """
  private static let \(genericGuardName): Void = ()
  """
}
