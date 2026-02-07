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

struct PlanMacroError: Error, CustomStringConvertible {
  var description: String
}

public struct PlanMacro: DeclarationMacro, Sendable {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard context.lexicalContext.isEmpty else {
      throw PlanMacroError(description: "Must be at file root")
    }

    guard let closureExpr = node.trailingClosure?.trimmed else {
      throw PlanMacroError(description: "Must have a result builder closure")
    }

    let filePath = context.location(of: node, at: .afterLeadingTrivia, filePathMode: .filePath)
      .map(\.file)
      .flatMap { $0.as(StringLiteralExprSyntax.self) }
      .flatMap(\.representedLiteralValue)
    if let filePath {
#if os(Windows)
      let slashIndex = filePath.lastIndex(of: #"\"#)
#else
      let slashIndex = filePath.lastIndex(of: "/")
#endif
      if let slashIndex {
        let fileName = filePath[slashIndex...].dropFirst()
        guard fileName.lowercased() == "testplan.swift" else {
          throw PlanMacroError(description: "Test plan must be declared in a file named 'TestPlan.swift', not '\(fileName)'")
        }
      }
    }

    var result = [DeclSyntax]()

    result.append(
      """
      @available(*, deprecated, message: "This property is an implementation detail of the testing library. Do not use it directly.")
      private let __testingPlan = Testing.Plan \(closureExpr)
      """
		)

    let testContentRecordName = context.makeUniqueName("")
    result.append(
      makeTestContentRecordDecl(
        named: testContentRecordName,
        in: nil,
        ofKind: .testPlan,
        accessingWith: """
        { outValue, type, _, _ in
          Testing.Plan.__store({ __testingPlan }, into: outValue, asTypeAt: type)
        }
        """,
        context: 0,
        in: context
      )
    )

#if compiler(<6.3)
    // Emit a type that contains a reference to the test content record.
    let enumName = context.makeUniqueName("__🟡$")
    result.append(
      """
      @available(*, deprecated, message: "This type is an implementation detail of the testing library. Do not use it directly.")
      enum \(enumName): Testing.__TestContentRecordContainer {
        nonisolated static var __testContentRecord: Testing.__TestContentRecord6_2 {
          unsafe \(testContentRecordName)
        }
      }
      """
    )
#endif

    return result
  }
  
}
