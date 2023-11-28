//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import TestingMacros

import SwiftDiagnostics
import SwiftOperators
import SwiftParser
public import SwiftSyntax
import SwiftSyntaxBuilder
public import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion

fileprivate let allMacros: [String: any Macro.Type] = [
  "expect": ExpectMacro.self,
  "require": RequireMacro.self,
  "Suite": SuiteDeclarationMacro.self,
  "Test": TestDeclarationMacro.self,
]

func parse(_ sourceCode: String, activeMacros activeMacroNames: [String] = [], removeWhitespace: Bool = false) throws -> (sourceCode: String, diagnostics: [Diagnostic]) {
  let activeMacros: [String: any Macro.Type]
  if activeMacroNames.isEmpty {
    activeMacros = allMacros
  } else {
    activeMacros = allMacros.filter { activeMacroNames.contains($0.key) }
  }
  let operatorTable = OperatorTable.standardOperators
  let originalSyntax = try operatorTable.foldAll(Parser.parse(source: sourceCode))
  let context = BasicMacroExpansionContext(expansionDiscriminator: "", sourceFiles: [:])
  let syntax = try operatorTable.foldAll(originalSyntax.expand(macros: activeMacros, in: context))
  var sourceCode = String(describing: syntax.formatted().trimmed)
  if removeWhitespace {
    sourceCode = sourceCode.filter { !$0.isWhitespace }
  }
  return (sourceCode, context.diagnostics)
}
