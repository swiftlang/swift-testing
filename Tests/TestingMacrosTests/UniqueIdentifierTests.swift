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

  @Test("Thunk identifiers contain a function's name")
  func thunkNameContainsFunctionName() throws {
    let uniqueName = try makeUniqueName("func someDistinctFunctionName() async throws")
    #expect(uniqueName.contains("someDistinctFunctionName"))
  }

  @Test("Thunk identifiers do not contain backticks")
  func noBackticks() throws {
    let uniqueName = try makeUniqueName("func `someDistinctFunctionName`() async throws")
    #expect(uniqueName.contains("someDistinctFunctionName"))

    #expect(!uniqueName.contains("`"))
  }

  @Test("Thunk identifiers do not contain arbitrary Unicode")
  func noArbitraryUnicode() throws {
    let uniqueName = try makeUniqueName("func someDistinctFunction🌮Name🐔() async throws")
    #expect(uniqueName.contains("someDistinctFunction"))

    #expect(!uniqueName.contains("🌮"))
    #expect(!uniqueName.contains("🐔"))
    #expect(uniqueName.contains("Name"))
  }

  @Test("Argument types influence generated identifiers")
  func argumentTypes() throws {
    let uniqueNameWithInt = try makeUniqueName("func someDistinctFunctionName(i: Int) async throws")
    #expect(uniqueNameWithInt.contains("someDistinctFunctionName"))
    let uniqueNameWithUInt = try makeUniqueName("func someDistinctFunctionName(i: UInt) async throws")
    #expect(uniqueNameWithUInt.contains("someDistinctFunctionName"))

    #expect(uniqueNameWithInt != uniqueNameWithUInt)
  }

  @Test("Effects influence generated identifiers")
  func effects() throws {
    let uniqueName = try makeUniqueName("func someDistinctFunctionName()")
    #expect(uniqueName.contains("someDistinctFunctionName"))
    let uniqueNameAsync = try makeUniqueName("func someDistinctFunctionName() async")
    #expect(uniqueNameAsync.contains("someDistinctFunctionName"))
    let uniqueNameThrows = try makeUniqueName("func someDistinctFunctionName() throws")
    #expect(uniqueNameThrows.contains("someDistinctFunctionName"))
    let uniqueNameAsyncThrows = try makeUniqueName("func someDistinctFunctionName() async throws")
    #expect(uniqueNameAsyncThrows.contains("someDistinctFunctionName"))

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
}
