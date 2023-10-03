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

@Suite("ConditionMacro Tests")
struct ConditionMacroTests {
  @Test("#expect() macro",
    arguments: [
      ##"#expect(true)"##:
        ##"Testing.__checkValue(true, sourceCode: .__fromSyntaxNode("true"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(false)"##:
        ##"Testing.__checkValue(false, sourceCode: .__fromSyntaxNode("false"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(false, "Custom message")"##:
        ##"Testing.__checkValue(false, sourceCode: .__fromSyntaxNode("false"), comments: ["Custom message"], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(2 > 1)"##:
        ##"Testing.__checkBinaryOperation(2, { $0 > $1() }, 1, sourceCode: .__fromBinaryOperation("2", ">", "1"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(((true || false) && true) || Bool.random())"##:
        ##"Testing.__checkBinaryOperation(((true || false) && true), { $0 || $1() }, Bool.random(), sourceCode: .__fromBinaryOperation("((true || false) && true)", "||", "Bool.random()"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(9 > 8 && 7 > 6, "Some comment")"##:
        ##"Testing.__checkBinaryOperation(9 > 8, { $0 && $1() }, 7 > 6, sourceCode: .__fromBinaryOperation("9 > 8", "&&", "7 > 6"), comments: ["Some comment"], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(!Bool.random())"##:
        ##"Testing.__checkValue(!Bool.random(), sourceCode: .__fromSyntaxNode("!Bool.random()"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect((true && false))"##:
        ##"Testing.__checkBinaryOperation(true, { $0 && $1() }, false, sourceCode: .__fromBinaryOperation("true", "&&", "false"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(try x())"##:
        ##"Testing.__checkValue(try x(), sourceCode: .__fromSyntaxNode("try x()"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(1 is Int)"##:
        ##"Testing.__checkCast(1, is: Int.self, sourceCode: .__fromBinaryOperation("1", "is", "Int"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect("123") { 1 == 2 } then: { foo() }"##:
        ##"Testing.__checkClosureCall(performing: { 1 == 2 }, then: { foo() }, sourceCode: .__fromBinaryOperation("1", "==", "2"), comments: ["123"], isRequired: false, sourceLocation:Testing.SourceLocation()).__expected()"##,
      ##"#expect("123") { let x = 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0 }, sourceCode: .__fromSyntaxNode("let x = 0"), comments: ["123"], isRequired: false, sourceLocation:Testing.SourceLocation()).__expected()"##,
      ##"#expect("123") { let x = 0; return x == 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0; return x == 0 }, sourceCode: .__fromSyntaxNode("{ let x = 0; return x == 0 }"), comments: ["123"], isRequired: false, sourceLocation:Testing.SourceLocation()).__expected()"##,
      ##"#expect(a, "b", c: c)"##:
        ##"Testing.__checkValue(a, c: c, sourceCode: .__fromSyntaxNode("a"), comments: ["b"], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(a())"##:
        ##"Testing.__checkFunctionCall((), calling: { _ in a() }, sourceCode: .__functionCall(nil, "a"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(b(c))"##:
        ##"Testing.__checkFunctionCall((), calling: { b($1) }, c, sourceCode: .__functionCall(nil, "b", (nil, "c")), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(a.b(c))"##:
        ##"Testing.__checkFunctionCall(a.self, calling: { $0.b($1) }, c, sourceCode: .__functionCall("a", "b", (nil, "c")), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(a.b(c, d: e))"##:
        ##"Testing.__checkFunctionCall(a.self, calling: { $0.b($1, d: $2) }, c, e, sourceCode: .__functionCall("a", "b", (nil, "c"), ("d", "e")), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(a.b(&c))"##:
        ##"Testing.__checkInoutFunctionCall(a.self, calling: { $0.b(&$1) }, &c, sourceCode: .__functionCall("a", "b", (nil, "&c")), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(a.b(&c, &d))"##:
        ##"Testing.__checkValue(a.b(&c, &d), sourceCode: .__fromSyntaxNode("a.b(&c, &d)"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(a.b(&c, d))"##:
        ##"Testing.__checkValue(a.b(&c, d), sourceCode: .__fromSyntaxNode("a.b(&c, d)"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(a.b(try c()))"##:
        ##"Testing.__checkValue(a.b(try c()), sourceCode: .__fromSyntaxNode("a.b(try c())"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect({}())"##:
        ##"Testing.__checkValue({}(), sourceCode: .__fromSyntaxNode("{}()"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(a.b(c: d))"##:
        ##"Testing.__checkFunctionCall(a.self, calling: { $0.b(c: $1) }, d, sourceCode: .__functionCall("a", "b", ("c", "d")), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(a.b { c })"##:
        ##"Testing.__checkValue(a.b { c }, sourceCode: .__fromSyntaxNode("a.b { c }"), comments: [], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()"##,
      ##"#expect(a, sourceLocation: someValue)"##:
        ##"Testing.__checkValue(a, sourceCode: .__fromSyntaxNode("a"), comments: [], isRequired: false, sourceLocation: someValue).__expected()"##,
    ]
  )
  func expectMacro(input: String, expectedOutput: String) throws {
    let (expectedOutput, _) = try parse(expectedOutput, removeWhitespace: true)
    let (actualOutput, _) = try parse(input, removeWhitespace: true)
    #expect(expectedOutput == actualOutput)
  }

  @Test("#require() macro",
    arguments: [
      ##"#require(true)"##:
        ##"Testing.__checkValue(true, sourceCode: .__fromSyntaxNode("true"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(false)"##:
        ##"Testing.__checkValue(false, sourceCode: .__fromSyntaxNode("false"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(false, "Custom message")"##:
        ##"Testing.__checkValue(false, sourceCode: .__fromSyntaxNode("false"), comments: ["Custom message"], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(2 > 1)"##:
        ##"Testing.__checkBinaryOperation(2, { $0 > $1() }, 1, sourceCode: .__fromBinaryOperation("2", ">", "1"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(((true || false) && true) || Bool.random())"##:
        ##"Testing.__checkBinaryOperation(((true || false) && true), { $0 || $1() }, Bool.random(), sourceCode: .__fromBinaryOperation("((true || false) && true)", "||", "Bool.random()"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(9 > 8 && 7 > 6, "Some comment")"##:
        ##"Testing.__checkBinaryOperation(9 > 8, { $0 && $1() }, 7 > 6, sourceCode: .__fromBinaryOperation("9 > 8", "&&", "7 > 6"), comments: ["Some comment"], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(!Bool.random())"##:
        ##"Testing.__checkValue(!Bool.random(), sourceCode: .__fromSyntaxNode("!Bool.random()"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require((true && false))"##:
        ##"Testing.__checkBinaryOperation(true, { $0 && $1() }, false, sourceCode: .__fromBinaryOperation("true", "&&", "false"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(try x())"##:
        ##"Testing.__checkValue(try x(), sourceCode: .__fromSyntaxNode("try x()"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(1 is Int)"##:
        ##"Testing.__checkCast(1, is: Int.self, sourceCode: .__fromBinaryOperation("1", "is", "Int"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require("123") { 1 == 2 } then: { foo() }"##:
        ##"Testing.__checkClosureCall(performing: { 1 == 2 }, then: { foo() }, sourceCode: .__fromBinaryOperation("1", "==", "2"), comments: ["123"], isRequired: true, sourceLocation:Testing.SourceLocation()).__required()"##,
      ##"#require("123") { let x = 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0 }, sourceCode: .__fromSyntaxNode("let x = 0"), comments: ["123"], isRequired: true, sourceLocation:Testing.SourceLocation()).__required()"##,
      ##"#require("123") { let x = 0; return x == 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0; return x == 0 }, sourceCode: .__fromSyntaxNode("{ let x = 0; return x == 0 }"), comments: ["123"], isRequired: true, sourceLocation:Testing.SourceLocation()).__required()"##,
      ##"#require(a, "b", c: c)"##:
        ##"Testing.__checkValue(a, c: c, sourceCode: .__fromSyntaxNode("a"), comments: ["b"], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(a())"##:
        ##"Testing.__checkFunctionCall((), calling: { _ in a() }, sourceCode: .__functionCall(nil, "a"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(b(c))"##:
        ##"Testing.__checkFunctionCall((), calling: { b($1) }, c, sourceCode: .__functionCall(nil, "b", (nil, "c")), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(a.b(c))"##:
        ##"Testing.__checkFunctionCall(a.self, calling: { $0.b($1) }, c, sourceCode: .__functionCall("a", "b", (nil, "c")), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(a.b(c, d: e))"##:
        ##"Testing.__checkFunctionCall(a.self, calling: { $0.b($1, d: $2) }, c, e, sourceCode: .__functionCall("a", "b", (nil, "c"), ("d", "e")), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(a.b(&c))"##:
        ##"Testing.__checkInoutFunctionCall(a.self, calling: { $0.b(&$1) }, &c, sourceCode: .__functionCall("a", "b", (nil, "&c")), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(a.b(&c, &d))"##:
        ##"Testing.__checkValue(a.b(&c, &d), sourceCode: .__fromSyntaxNode("a.b(&c, &d)"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(a.b(&c, d))"##:
        ##"Testing.__checkValue(a.b(&c, d), sourceCode: .__fromSyntaxNode("a.b(&c, d)"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(a.b(try c()))"##:
        ##"Testing.__checkValue(a.b(try c()), sourceCode: .__fromSyntaxNode("a.b(try c())"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require({}())"##:
        ##"Testing.__checkValue({}(), sourceCode: .__fromSyntaxNode("{}()"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(a.b(c: d))"##:
        ##"Testing.__checkFunctionCall(a.self, calling: { $0.b(c: $1) }, d, sourceCode: .__functionCall("a", "b", ("c", "d")), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(a.b { c })"##:
        ##"Testing.__checkValue(a.b { c }, sourceCode: .__fromSyntaxNode("a.b { c }"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(a, sourceLocation: someValue)"##:
        ##"Testing.__checkValue(a, sourceCode: .__fromSyntaxNode("a"), comments: [], isRequired: true, sourceLocation: someValue).__required()"##,
    ]
  )
  func requireMacro(input: String, expectedOutput: String) throws {
    let (expectedOutput, _) = try parse(expectedOutput, removeWhitespace: true)
    let (actualOutput, _) = try parse(input, removeWhitespace: true)
    #expect(expectedOutput == actualOutput)
  }

  @Test("Unwrapping #require() macro",
    arguments: [
      ##"#require(Optional<Int>.none)"##:
        ##"Testing.__checkValue(Optional<Int>.none, sourceCode: .__fromSyntaxNode("Optional<Int>.none"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(nil ?? 123)"##:
        ##"Testing.__checkBinaryOperation(nil, { $0 ?? $1() }, 123, sourceCode: .__fromBinaryOperation("nil", "??", "123"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(123 ?? nil)"##:
        ##"Testing.__checkBinaryOperation(123, { $0 ?? $1() }, nil, sourceCode: .__fromBinaryOperation("123", "??", "nil"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(123 as? Double)"##:
        ##"Testing.__checkCast(123,as: Double.self, sourceCode: .__fromBinaryOperation("123", "as?", "Double"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(123 as Double)"##:
        ##"Testing.__checkValue(123 as Double, sourceCode: .__fromSyntaxNode("123 as Double"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
      ##"#require(123 as! Double)"##:
        ##"Testing.__checkValue(123 as! Double, sourceCode: .__fromSyntaxNode("123 as! Double"), comments: [], isRequired: true, sourceLocation: Testing.SourceLocation()).__required()"##,
    ]
  )
  func unwrappingRequireMacro(input: String, expectedOutput: String) throws {
    let (expectedOutput, _) = try parse(expectedOutput)
    let (actualOutput, _) = try parse(input)
    #expect(expectedOutput == actualOutput)
  }

  @Test("Capturing comments above #expect()/#require()",
    arguments: [
      """
      // Source comment
      /** Doc comment */
      #expect(try x(), "Argument comment")
      """:
      """
      // Source comment
      /** Doc comment */
      Testing.__checkValue(try x(), sourceCode: .__fromSyntaxNode("try x()"), comments: [.__line("// Source comment"),.__documentationBlock("/** Doc comment */"),"Argument comment"], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()
      """,

      """
      // Ignore me

      // Capture me
      #expect(try x())
      """:
      """
      // Ignore me

      // Capture me
      Testing.__checkValue(try x(), sourceCode: .__fromSyntaxNode("try x()"), comments: [.__line("// Capture me")], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()
      """,

      """
      // Ignore me
      \t
      // Capture me
      #expect(try x())
      """:
      """
      // Ignore me
      \t
      // Capture me
      Testing.__checkValue(try x(), sourceCode: .__fromSyntaxNode("try x()"), comments: [.__line("// Capture me")], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()
      """,
    ]
  )
  func commentCapture(input: String, expectedOutput: String) throws {
    let (expectedOutput, _) = try parse(expectedOutput)
    let (actualOutput, _) = try parse(input)
    #expect(expectedOutput == actualOutput)
  }

  @Test("#expect(false) and #require(false) warn they always fail",
    arguments: ["#expect(false)", "#require(false)","#expect(!true)","#require(!true)"]
  )
  func expectAndRequireMacroWarnsForFailure(input: String) throws {
    let (_, diagnostics) = try parse(input)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.diagMessage.severity == .warning)
    #expect(diagnostic.message.contains("will always fail"))
  }

  @Test("#expect(true) and #require(true) note they always pass",
    arguments: ["#expect(true)", "#require(true)","#expect(!false)","#require(!false)"]
  )
  func expectAndRequireMacroWarnsForPassing(input: String) throws {
    let (_, diagnostics) = try parse(input)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.diagMessage.severity == .note)
    #expect(diagnostic.message.contains("will always pass"))
  }

  @Test("Bool(false) suppresses the warning about always failing",
    arguments: ["#expect(Bool(false))", "#require(Bool(false))","#expect(Bool(!true))","#require(Bool(!true))"]
  )
  func expectAndRequireMacroWarningSuppressedWithExplicitBoolInitializer(input: String) throws {
    let (_, diagnostics) = try parse(input)
    #expect(diagnostics.count == 0)
  }

  @Test("as! warns when used with #require()",
    arguments: ["#expect(x as! T)", "#require(x as! T)",]
  )
  func asExclamationMarkWarnsWithRequire(input: String) throws {
    let (_, diagnostics) = try parse(input)
    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.diagMessage.severity == .warning)
    #expect(diagnostic.message.contains("will be evaluated before"))
  }

  @Test("as! warning is suppressed for explicit Bool and Optional casts",
    arguments: [
      "#expect(x as! Bool)", "#require(x as! Bool)",
      "#expect(x as! T?)", "#require(x as! T?)",
      "#expect(x as! T!)", "#require(x as! T!)",
      "#expect(x as! Optional<T>)", "#require(x as! Optional<T>)",
      "#expect(x as! Swift.Optional<T>)", "#require(x as! Swift.Optional<T>)",
    ]
  )
  func asExclamationMarkSuppressedForBoolAndOptional(input: String) throws {
    let (_, diagnostics) = try parse(input)
    #expect(diagnostics.count == 0)
  }

  @Test("Macro expansion is performed within a test function")
  func macroExpansionInTestFunction() throws {
    let input = ##"""
      @Test("Random number generation") func rng() {
        let number = Int.random(in: 1 ..< .max)
        #expect((number > 0 && foo() != bar(at: 9)) != !true, "\(number) must be greater than 0")
      }
    """##

    let rawExpectedOutput = ##"""
      @Test("Random number generation") func rng() {
        let number = Int.random(in: 1 ..< .max)
        Testing.__checkBinaryOperation((number > 0 && foo() != bar(at: 9)), { $0 != $1() }, !true, sourceCode: .__fromBinaryOperation("(number > 0 && foo() != bar(at: 9))", "!=", "!true"), comments: ["\(number) must be greater than 0"], isRequired: false, sourceLocation: Testing.SourceLocation()).__expected()
      }
    """##

    let (expectedOutput, _) = try parse(rawExpectedOutput, activeMacros: ["expect"], removeWhitespace: true)
    let (actualOutput, _) = try parse(input, activeMacros: ["expect"], removeWhitespace: true)
    #expect(expectedOutput == actualOutput)
  }
}
