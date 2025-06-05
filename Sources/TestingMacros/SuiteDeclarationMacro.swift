//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftDiagnostics
public import SwiftSyntax
import SwiftSyntaxBuilder
public import SwiftSyntaxMacros

#if !hasFeature(SymbolLinkageMarkers) && SWT_NO_LEGACY_TEST_DISCOVERY
#error("Platform-specific misconfiguration: either SymbolLinkageMarkers or legacy test discovery is required to expand @Suite")
#endif

public struct SuiteWithArgumentsDeclarationMacro: ExtensionMacro, PeerMacro, Sendable {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard SuiteDeclarationMacro.diagnoseIssues(with: declaration, suiteAttribute: node, in: context) else {
      return []
    }

    // TODO: gather all stored properties in the declaration and use them
    // instead of requiring a custom initializer
    let propertyBindings = declaration.memberBlock.members
      .compactMap(\.decl)
      .compactMap { $0.as(VariableDeclSyntax.self) }
      .filter { !$0.isStaticOrClass }
      .flatMap(\.bindings)
    let storedPropertyBindings = propertyBindings.filter { binding in
      guard let accessorBlock = binding.accessorBlock else {
        // No bindings, so must be a stored property. FIXME: accessor macros?
        return true
      }
      switch accessorBlock.accessors {
      case let .accessors(accessors):
        // TODO: verify this is the correct or best-possible logic
        let accessorsAllowedOnStoredProperties: [TokenKind] = [
          .keyword(.didSet), .keyword(.willSet), .keyword(.`init`)
        ]
        return accessors
          .map(\.accessorSpecifier.tokenKind)
          .allSatisfy(accessorsAllowedOnStoredProperties.contains)
      case .getter:
        // A variable with a single getter is always computed.
        return false
      }
    }

    let storedPropertyTypes = storedPropertyBindings.compactMap { binding in
      if let type = binding.typeAnnotation?.type {
        return type
      } else if let valueExpr = binding.initializer?.value {
        switch valueExpr.kind {
        case .integerLiteralExpr:
          return TypeSyntax(IdentifierTypeSyntax(name: .identifier("IntegerLiteralType")))
        case .floatLiteralExpr:
          return TypeSyntax(IdentifierTypeSyntax(name: .identifier("FloatLiteralType")))
        case .booleanLiteralExpr:
          return TypeSyntax(IdentifierTypeSyntax(name: .identifier("BooleanLiteralType")))
        case .stringLiteralExpr, .simpleStringLiteralExpr:
          return TypeSyntax(IdentifierTypeSyntax(name: .identifier("StringLiteralType")))
        default:
          break
        }
      }

      context.diagnose(
        DiagnosticMessage(
          syntax: Syntax(binding),
          message: "Could not infer the type of stored property '\(binding.pattern.trimmed)' in parameterized test suite '\(type.trimmed)'",
          severity: .error
        )
      )
      return nil
    }
    guard storedPropertyTypes.count == storedPropertyBindings.count else {
      return []
    }

    let parameters: [(label: TokenSyntax, type: TypeSyntax)] = zip(storedPropertyBindings, storedPropertyTypes).map { binding, type in
      guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
        context.diagnose(
          DiagnosticMessage(
            syntax: Syntax(binding.pattern),
            message: "Could not infer the name of stored property '\(binding.pattern.trimmed)' in parameterized test suite '\(type.trimmed)'",
            severity: .error
          )
        )
        return (label: .wildcardToken(), type: type)
      }
      return (label: identifier, type: type)
    }

    return [
      SuiteDeclarationMacro.createExtensionDecl(
        for: declaration,
        ofType: type,
        withParameters: parameters,
        suiteAttribute: node,
        in: context
      )
    ]
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // The peer macro expansion of this macro is only used to diagnose misuses
    // on symbols that are not decl groups.
    if !declaration.isProtocol((any DeclGroupSyntax).self) {
      _ = SuiteDeclarationMacro.diagnoseIssues(with: declaration, suiteAttribute: node, in: context)
    }
    return []
  }

  public static var formatMode: FormatMode {
    .disabled
  }
}

/// A type describing the expansion of the `@Suite` attribute macro.
///
/// This type is used to implement the `@Suite` attribute macro. Do not use it
/// directly.
public struct SuiteDeclarationMacro: ExtensionMacro, PeerMacro, Sendable {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard diagnoseIssues(with: declaration, suiteAttribute: node, in: context) else {
      return []
    }
    return [createExtensionDecl(for: declaration, ofType: type, withParameters: [], suiteAttribute: node, in: context)]
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // The peer macro expansion of this macro is only used to diagnose misuses
    // on symbols that are not decl groups.
    if !declaration.isProtocol((any DeclGroupSyntax).self) {
      _ = diagnoseIssues(with: declaration, suiteAttribute: node, in: context)
    }
    return []
  }

  public static var formatMode: FormatMode {
    .disabled
  }

  /// Diagnose issues with a `@Suite` declaration.
  ///
  /// - Parameters:
  ///   - declaration: The type declaration to diagnose.
  ///   - suiteAttribute: The `@Suite` attribute applied to `declaration`.
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: Whether or not macro expansion should continue (i.e. stopping
  ///   if a fatal error was diagnosed.)
  fileprivate static func diagnoseIssues(
    with declaration: some DeclSyntaxProtocol,
    suiteAttribute: AttributeSyntax,
    in context: some MacroExpansionContext
  ) -> Bool {
    var diagnostics = [DiagnosticMessage]()
    defer {
      context.diagnose(diagnostics)
    }

    // Check if the lexical context is appropriate for a suite or test.
    diagnostics += diagnoseIssuesWithLexicalContext(context.lexicalContext, containing: declaration, attribute: suiteAttribute)
    diagnostics += diagnoseIssuesWithLexicalContext(declaration, containing: declaration, attribute: suiteAttribute)

    // Suites inheriting from XCTestCase are not supported. This check is
    // duplicated in TestDeclarationMacro but is not part of
    // diagnoseIssuesWithLexicalContext() because it doesn't need to recurse
    // across the entire lexical context list, just the innermost type
    // declaration.
    if let declaration = declaration.asProtocol((any DeclGroupSyntax).self),
       declaration.inherits(fromTypeNamed: "XCTestCase", inModuleNamed: "XCTest") {
      diagnostics.append(.xcTestCaseNotSupported(declaration, whenUsing: suiteAttribute))
    }

    // @Suite cannot be applied to a type extension (although a type extension
    // can still contain test functions and test suites.)
    if let extensionDecl = declaration.as(ExtensionDeclSyntax.self) {
      diagnostics.append(.attributeHasNoEffect(suiteAttribute, on: extensionDecl))
    }

    // Check other attributes on the declaration. Note that it should be
    // impossible to reach this point if the declaration can't have attributes.
    if let attributedDecl = declaration.asProtocol((any WithAttributesSyntax).self) {
      // Only one @Suite attribute is supported.
      let suiteAttributes = attributedDecl.attributes(named: "Suite")
      if suiteAttributes.count > 1 {
        diagnostics.append(.multipleAttributesNotSupported(suiteAttributes, on: declaration))
      }
    }

    return !diagnostics.lazy.map(\.severity).contains(.error)
  }

  /// Create the declarations necessary to discover a suite at runtime.
  ///
  /// - Parameters:
  ///   - declaration: The type declaration the result should encapsulate.
  ///   - suiteAttribute: The `@Suite` attribute applied to `declaration`.
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: An array of declarations providing runtime information about
  ///   the test suite type `declaration`.
  private static func _createSuiteDecls(
    for declaration: some DeclGroupSyntax,
    ofType declarationType: some TypeSyntaxProtocol,
    withParameters parameters: [(label: TokenSyntax, type: TypeSyntax)],
    suiteAttribute: AttributeSyntax,
    in context: some MacroExpansionContext
  ) -> [DeclSyntax] {
    var result = [DeclSyntax]()

    if declaration.is(ExtensionDeclSyntax.self) {
      // No declaration is emitted for an extension. One can be synthesized at
      // runtime if one is not available for the type declaration itself.
      return []
    }

    if let genericGuardDecl = makeGenericGuardDecl(guardingAgainst: declaration, in: context) {
      result.append(genericGuardDecl)
    }

    // Parse the @Suite attribute.
    let attributeInfo = AttributeInfo(byParsing: suiteAttribute, on: declaration, in: context)

    if let testFunctionArguments = attributeInfo.testFunctionArguments, testFunctionArguments.count != parameters.count {
      // TODO: diagnose this, but suppress for zip()ped args?
    }

    let parameterListExpr = ArrayExprSyntax {
      for parameter in parameters {
        ArrayElementSyntax(
          expression: TupleExprSyntax {
            LabeledExprSyntax(label: "firstName", expression: StringLiteralExprSyntax(content: parameter.label.textWithoutBackticks))
            LabeledExprSyntax(label: "secondName", expression: NilLiteralExprSyntax())
            LabeledExprSyntax(label: "type", expression: "\(parameter.type.trimmed).self" as ExprSyntax)
          }
        )
      }
    }

    let generatorName = context.makeUniqueName("generator")
    result.append(
      """
      @available(*, deprecated, message: "This property is an implementation detail of the testing library. Do not use it directly.")
      @Sendable private static func \(generatorName)() async -> Testing.Test {
        .__type(
          \(declarationType.trimmed).self,
          \(raw: attributeInfo.functionArgumentList(in: context)),
      		parameters: \(parameterListExpr)
        )
      }
      """
    )

    let accessorName = context.makeUniqueName("accessor")
    result.append(
      """
      @available(*, deprecated, message: "This property is an implementation detail of the testing library. Do not use it directly.")
      private nonisolated static let \(accessorName): Testing.__TestContentRecordAccessor = { outValue, type, _, _ in
        Testing.Test.__store(\(generatorName), into: outValue, asTypeAt: type)
      }
      """
    )

    let testContentRecordName = context.makeUniqueName("testContentRecord")
    result.append(
      makeTestContentRecordDecl(
        named: testContentRecordName,
        in: TypeSyntax(declarationType),
        ofKind: .testDeclaration,
        accessingWith: accessorName,
        context: attributeInfo.testContentRecordFlags
      )
    )

#if !SWT_NO_LEGACY_TEST_DISCOVERY
    // Emit a type that contains a reference to the test content record.
    let enumName = context.makeUniqueName("__🟡$")
    let unsafeKeyword: TokenSyntax? = isUnsafeKeywordSupported ? .keyword(.unsafe, trailingTrivia: .space) : nil
    result.append(
      """
      @available(*, deprecated, message: "This type is an implementation detail of the testing library. Do not use it directly.")
      enum \(enumName): Testing.__TestContentRecordContainer {
        nonisolated static var __testContentRecord: Testing.__TestContentRecord {
          \(unsafeKeyword)\(testContentRecordName)
        }
      }
      """
    )
#endif

    return result
  }

  fileprivate static func createExtensionDecl(
    for declaration: some DeclGroupSyntax,
    ofType declarationType: some TypeSyntaxProtocol,
    withParameters parameters: [(label: TokenSyntax, type: TypeSyntax)],
    suiteAttribute: AttributeSyntax,
    in context: some MacroExpansionContext
  ) -> ExtensionDeclSyntax {
    let decls = _createSuiteDecls(for: declaration, ofType: declarationType, withParameters: parameters, suiteAttribute: suiteAttribute, in: context)
    var codeBlock = CodeBlockItemListSyntax {
      for decl in decls {
        decl
      }
    }

    let suiteProtocolType: TypeSyntax
    if parameters.isEmpty {
      suiteProtocolType = "Testing.__Suite"
    } else {
      suiteProtocolType = "Testing.__SuiteWithArguments"

      let suiteArgumentsType: TypeSyntax = if parameters.count == 1 {
        parameters[0].type.trimmed
      } else {
        TypeSyntax(
          TupleTypeSyntax(
            elements: TupleTypeElementListSyntax {
              for parameter in parameters {
                TupleTypeElementSyntax(
                  firstName: parameter.label.trimmed,
                  colon: .colonToken(trailingTrivia: .space),
                  type: parameter.type.trimmed
                )
              }
            }
          )
        )
      }
      codeBlock = CodeBlockItemListSyntax {
        "typealias __SuiteArguments = \(suiteArgumentsType)"
        codeBlock
      }
    }

    let result: DeclSyntax = """
    extension \(declarationType.trimmed): \(suiteProtocolType) {
      \(codeBlock)
    }
    """

    return result.cast(ExtensionDeclSyntax.self)
  }
}
