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

import SwiftParser
import SwiftSyntax

@Suite("PragmaMacro Tests")
struct PragmaMacroTests {
  @Test func findSemantics() throws {
    let node = """
    @Testing.__testing(semantics: "abc123")
    @__testing(semantics: "def456")
    let x = 0
    """ as DeclSyntax
    let nodeWithAttributes = try #require(node.asProtocol((any WithAttributesSyntax).self))
    let semantics = semantics(of: nodeWithAttributes)
    #expect(semantics == ["abc123", "def456"])
  }

  @Test func warningGenerated() throws {
    let sourceCode = """
    @__testing(warning: "abc123")
    let x = 0
    """

    let (_, diagnostics) = try parse(sourceCode)
    #expect(diagnostics.count == 1)
    #expect(diagnostics[0].message == "abc123")
    #expect(diagnostics[0].diagMessage.severity == .warning)
  }
}
