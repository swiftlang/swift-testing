//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

public import SwiftSyntax
public import SwiftSyntaxMacros

public struct AttributedDeclarationSyntax<D> where D: DeclSyntaxProtocol {
  public var attribute: AttributeSyntax
  public var declaration: D

  public var displayName: StringLiteralExprSyntax?
  public var traits: [ExprSyntax]
  public var arguments: [ExprSyntax]
}

public typealias TestDeclarationSyntax = AttributedDeclarationSyntax<FunctionDeclSyntax>
public typealias SuiteDeclarationSyntax<D> = AttributedDeclarationSyntax<D> where D: DeclSyntaxProtocol & DeclGroupSyntax & WithAttributesSyntax

@available(*, unavailable)
extension TestDeclarationSyntax: Sendable {}

// MARK: -

extension AttributedDeclarationSyntax {
  fileprivate init(attribute: AttributeSyntax, declaration: D, in context: some MacroExpansionContext) {
    let attributeInfo = AttributeInfo(byParsing: attribute, on: declaration, in: context)

    self.attribute = attribute
    self.declaration = declaration

    self.displayName = attributeInfo.displayName
    self.traits = attributeInfo.traits
    // TODO: don't assume otherArguments is only parameterized function arguments
    self.arguments = attributeInfo.otherArguments.map(\.expression)
  }
}

extension TestDeclarationSyntax {
  public init?(for functionDecl: FunctionDeclSyntax, in context: some MacroExpansionContext) {
    guard let attribute = functionDecl.attributes(named: "Test", inModuleNamed: "Testing", in: context).first else {
      return nil
    }
    self.init(attribute: attribute, declaration: functionDecl, in: context)
  }
}

extension SuiteDeclarationSyntax {
  public init?(for declGroup: D, in context: some MacroExpansionContext) {
    guard let attribute = declGroup.attributes(named: "Suite", inModuleNamed: "Testing", in: context).first else {
      return nil
    }
    self.init(attribute: attribute, declaration: declGroup, in: context)
  }
}
