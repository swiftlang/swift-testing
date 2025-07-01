//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Testing
@testable import TestingMacros

import SwiftDiagnostics
import SwiftOperators
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion

@Suite("Unique Identifier Tests")
struct UniqueIdentifierTests {
  func makeUniqueName(_ functionDeclString: String) throws -> String {
    let decl = "\(raw: functionDeclString)" as DeclSyntax
    let functionDecl = try #require(decl.as(FunctionDeclSyntax.self))
    return BasicMacroExpansionContext().makeUniqueName(thunking: functionDecl).text
  }

  @Test("Thunk identifiers do not contain backticks")
  func noBackticks() throws {
    let uniqueName = try makeUniqueName("func `someDistinctFunctionName`() async throws")

    #expect(!uniqueName.contains("`"))
  }

  @Test("Thunk identifiers do not contain arbitrary Unicode")
  func noArbitraryUnicode() throws {
    let uniqueName = try makeUniqueName("func someDistinctFunction🌮Name🐔() async throws")

    #expect(!uniqueName.contains("🌮"))
    #expect(!uniqueName.contains("🐔"))
  }

  @Test("Argument types influence generated identifiers")
  func argumentTypes() throws {
    let uniqueNameWithInt = try makeUniqueName("func someDistinctFunctionName(i: Int) async throws")
    let uniqueNameWithUInt = try makeUniqueName("func someDistinctFunctionName(i: UInt) async throws")

    #expect(uniqueNameWithInt != uniqueNameWithUInt)
  }

  @Test("Effects influence generated identifiers")
  func effects() throws {
    let uniqueName = try makeUniqueName("func someDistinctFunctionName()")
    let uniqueNameAsync = try makeUniqueName("func someDistinctFunctionName() async")
    let uniqueNameThrows = try makeUniqueName("func someDistinctFunctionName() throws")
    let uniqueNameAsyncThrows = try makeUniqueName("func someDistinctFunctionName() async throws")

    #expect(uniqueName != uniqueNameAsync)
    #expect(uniqueName != uniqueNameThrows)
    #expect(uniqueName != uniqueNameAsyncThrows)
    #expect(uniqueNameThrows != uniqueNameAsync)
    #expect(uniqueNameThrows != uniqueNameAsyncThrows)
    #expect(uniqueNameAsync != uniqueNameAsyncThrows)
  }

  @Test("Unicode characters influence generated identifiers")
  func unicode() throws {
    let uniqueName1 = try makeUniqueName("func A(🙃: Int)")
    let uniqueName2 = try makeUniqueName("func A(🙂: Int)")
    let uniqueName3 = try makeUniqueName("func A(i: Int)")
    #expect(uniqueName1 != uniqueName2)
    #expect(uniqueName1 != uniqueName3)
    #expect(uniqueName2 != uniqueName3)
  }

  @Test("Body does not influence generated identifiers")
  func body() throws {
    let uniqueName1 = try makeUniqueName("func f() { abc() }")
    let uniqueName2 = try makeUniqueName("func f() { def() }")
    #expect(uniqueName1 == uniqueName2)
  }



  @Test("Duplicate function names generate different identifiers")
  func duplicateFunctionNames() throws {
    // Test that calling makeUniqueName twice with the same base name
    // generates different identifiers
    let context = BasicMacroExpansionContext()
    let name1 = context.makeUniqueName("test")
    let name2 = context.makeUniqueName("test")
    
    #expect(name1.text != name2.text)
  }
}
