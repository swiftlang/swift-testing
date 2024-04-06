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
#if !canImport(SwiftSyntax600)
    // The whitespace hack we perform for swift-syntax-510 cannot "see" the
    // leading whitespace when the entire syntax tree of interest is on a single
    // line. Run the input through formatting before applying macros so that it
    // is expanded out into a multi-line string.
    let input = Parser.parse(source: input).formatted().trimmedDescription
#endif
    let (output, diagnostics) = try parse(input)
    #expect(diagnostics.count == 0)
#if canImport(SwiftSyntax600)
    #expect(output.contains("__fromStaticMember(of: \(typeName).self,"))
#else
    #expect(output.contains("__fromStaticMember(of: Self.self,"))
#endif
    #expect(output.contains(#""x")"#))
  }

  static var apiMisuseErrors: [String: String] {
    var result = [
      "@Tag struct S {}":
        "Attribute 'Tag' cannot be applied to a structure",
      "@Tag var x: Tag":
        "Attribute 'Tag' cannot be applied to a global variable",
      "@Tag nonisolated var x: Tag":
        "Attribute 'Tag' cannot be applied to a global variable",
      "@Tag static var x: Tag":
        "Attribute 'Tag' cannot be applied to a global variable",
    ]

#if canImport(SwiftSyntax600)
    let swiftSyntax600Misuses = [
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
    result.merge(swiftSyntax600Misuses, uniquingKeysWith: { lhs, _ in lhs })
#else
    let swiftSyntax510Misuses = [
      "{ @Tag var x: Tag }":
        "Attribute 'Tag' cannot be applied to an instance property",
      "{ @Tag nonisolated var x: Tag }":
        "Attribute 'Tag' cannot be applied to an instance property",
    ]
    result.merge(swiftSyntax510Misuses, uniquingKeysWith: { lhs, _ in lhs })
#endif

    return result
  }

  @Test("Error diagnostics emitted on API misuse", arguments: apiMisuseErrors)
  func apiMisuseErrors(input: String, expectedMessage: String) throws {
#if !canImport(SwiftSyntax600)
    // The whitespace hack we perform for swift-syntax-510 cannot "see" the
    // leading whitespace when the entire syntax tree of interest is on a single
    // line. Run the input through formatting before applying macros so that it
    // is expanded out into a multi-line string.
    let input = Parser.parse(source: input).formatted().trimmedDescription
#endif
    let (_, diagnostics) = try parse(input)

    #expect(diagnostics.count > 0)
    for diagnostic in diagnostics {
      #expect(diagnostic.diagMessage.severity == .error)
      #expect(diagnostic.message == expectedMessage)
    }
  }
}
