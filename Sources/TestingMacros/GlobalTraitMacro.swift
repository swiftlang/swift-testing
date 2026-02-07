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

struct GlobalTraitMacroError: Error, CustomStringConvertible {
  var description: String
}

public struct GlobalTraitMacro: DeclarationMacro, Sendable {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard context.lexicalContext.isEmpty else {
      throw GlobalTraitMacroError(description: "Must be at file root")
    }

    let arguments = LabeledExprListSyntax {
      node.arguments
        .map(Argument.init)
        .map(LabeledExprSyntax.init)
    }

    var result = [DeclSyntax]()

    let testContentRecordName = context.makeUniqueName("")
    result.append(
      makeTestContentRecordDecl(
        named: testContentRecordName,
        in: nil,
        ofKind: .globalTrait,
        accessingWith: """
        { outValue, type, _, _ in
          Testing.__store(
            \(arguments),
            into: outValue,
            asTypeAt: type
        	)
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
