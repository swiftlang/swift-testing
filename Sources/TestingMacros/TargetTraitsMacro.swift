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
public import SwiftSyntax
import SwiftSyntaxBuilder
public import SwiftSyntaxMacros

/// A type describing the expansion of the `@Test` attribute macro.
///
/// This type is used to implement the `@Test` attribute macro. Do not use it
/// directly.
public struct TargetTraitsMacro: DeclarationMacro, Sendable {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    if node.arguments.isEmpty {
      // TODO: emit a warning
      return []
    }

    guard context.lexicalContext.isEmpty else {
      // TODO: emit a proper diagnostic
      fatalError("Cannot declare target traits nested in something, must be at top level")
    }

    var result = [DeclSyntax]()

    let targetTraitsExpr = ArrayExprSyntax {
      for argumentExpr in node.arguments.map(\.expression) {
        ArrayElementSyntax(expression: argumentExpr.trimmed)
      }
    }
    let targetTraitsName = context.makeUniqueName("targetTraits")
    result.append(
      """
      @available(*, deprecated, message: "This type is an implementation detail of the testing library. Do not use it directly.")
      @Sendable func \(targetTraitsName)() async -> [any Testing.TargetTrait] {
        \(applyEffectfulKeywords([.await, .unsafe], to: targetTraitsExpr))
      }
      """
    )

    let accessorName = context.makeUniqueName("accessor")
    result.append(
      """
      @available(*, deprecated, message: "This property is an implementation detail of the testing library. Do not use it directly.")
      private nonisolated let \(accessorName): Testing.__TestContentRecordAccessor = { outValue, type, _, _ in
        Testing.__store(\(targetTraitsName), into: outValue, asTypeAt: type)
      }
      """
    )

    let testContentRecordName = context.makeUniqueName("testContentRecord")
    result.append(
      makeTestContentRecordDecl(
        named: testContentRecordName,
        ofKind: .targetTraits,
        accessingWith: accessorName,
        context: 0
      )
    )

#if !SWT_NO_LEGACY_TEST_DISCOVERY
    // Emit a type that contains a reference to the test content record.
    let enumName = context.makeUniqueName("__🟡$")
    result.append(
      """
      @available(*, deprecated, message: "This type is an implementation detail of the testing library. Do not use it directly.")
      enum \(enumName): Testing.__TestContentRecordContainer {
        nonisolated static var __testContentRecord: Testing.__TestContentRecord {
          \(testContentRecordName)
        }
      }
      """
    )
#endif

    return result
  }
}
