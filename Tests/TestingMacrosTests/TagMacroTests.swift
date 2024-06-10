//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Testing
@testable import TestingMacros

import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@Suite("TagMacro Tests")
struct TagMacroTests {
  @Test("@Tag macro",
    arguments: [
      ("extension Tag { @Tag static var x: Tag }", "Tag"),
      ("extension Tag { @Tag static var x: Self }", "Tag"),
      ("extension Testing.Tag { @Tag static var x: Testing.Tag }", "Testing.Tag"),
      ("extension Tag.A.B { @Tag static var x: Tag }", "Tag.A.B"),
      ("extension Testing.Tag.A.B { @Tag static var x: Tag }", "Testing.Tag.A.B"),
      ("extension Tag { struct S { @Tag static var x: Tag } }", "Tag.S"),
      ("extension Testing.Tag { enum E { @Tag static var x: Tag } }", "Testing.Tag.E"),
    ]
  )
  func tagMacro(input: String, typeName: String) throws {
    let (output, diagnostics) = try parse(input)
    #expect(diagnostics.count == 0)
    #expect(output.contains("__fromStaticMember(of: \(typeName).self,"))
    #expect(output.contains(#""x")"#))
  }

  @Test("Error diagnostics emitted on API misuse",
    arguments: [
      "@Tag struct S {}":
        "Attribute 'Tag' cannot be applied to a structure",
      "@Tag var x: Tag":
        "Attribute 'Tag' cannot be applied to a global variable",
      "@Tag nonisolated var x: Tag":
        "Attribute 'Tag' cannot be applied to a global variable",
      "@Tag static var x: Tag":
        "Attribute 'Tag' cannot be applied to a global variable",

      "extension Tag { @Tag var x: Tag }":
        "Attribute 'Tag' cannot be applied to an instance property",
      "extension Tag { @Tag nonisolated var x: Tag }":
        "Attribute 'Tag' cannot be applied to an instance property",
      "struct S { @Tag static var x: Tag }":
        "Attribute 'Tag' cannot be applied to a property except in an extension to 'Tag'",
      "extension Tag { @Tag static var x: String }":
        "Attribute 'Tag' cannot be applied to a property of type 'String'",
      "extension Tag.A.B { @Tag static var x: Self }":
        "Attribute 'Tag' cannot be applied to a property of type 'Tag.A.B'",
    ]
  )
  func apiMisuseErrors(input: String, expectedMessage: String) throws {
    let (_, diagnostics) = try parse(input)

    #expect(diagnostics.count > 0)
    for diagnostic in diagnostics {
      #expect(diagnostic.diagMessage.severity == .error)
      #expect(diagnostic.message == expectedMessage)
    }
  }
}
