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
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(true, "") }, sourceCode: ["": "true"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(false)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(false, "") }, sourceCode: ["": "false"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(false, "Custom message")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(false, "") }, sourceCode: ["": "false"], comments: ["Custom message"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(2 > 1)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(2 > 1, "") }, sourceCode: ["": "2 > 1"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(((true || false) && true) || Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(((true || false) && true), "2") || __ec(__ec(Bool.self, "e000000").random(), "2000000"), "") }, sourceCode: ["": "((true || false) && true) || Bool.random()", "2": "((true || false) && true)", "2000000": "Bool.random()", "e000000": "Bool"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(9 > 8 && 7 > 6, "Some comment")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(9 > 8, "2") && __ec(7 > 6, "400"), "") }, sourceCode: ["": "9 > 8 && 7 > 6", "2": "9 > 8", "400": "7 > 6"], comments: ["Some comment"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("a" == "b")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec.__cmp("a" , "2", "b", "200", { $0 == $1 }, "") }, sourceCode: ["": #""a" == "b""#, "2": #""a""#, "200": #""b""#], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(!Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(!__ec(__ec(Bool.self, "1c").random(), "4"), "") }, sourceCode: ["": "!Bool.random()", "4": "Bool.random()", "1c": "Bool"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect((true && false))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec((true && false), "") }, sourceCode: ["": "(true && false)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(try x())"##:
        ##"try Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(try __ec(x(), "4")) }, sourceCode: ["4": "x()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(1 is Int)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec.__is(1 , __ec((Int).self, "10"), "10"), "") }, sourceCode: ["": "1 is Int", "10": "Int"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("123") { 1 == 2 } then: { foo() }"##:
        ##"Testing.__checkClosureCall(performing: { 1 == 2 }, then: { foo() }, sourceCode: "1 == 2", comments: ["123"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("123") { let x = 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0 }, sourceCode: "let x = 0", comments: ["123"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("123") { let x = 0; return x == 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0; return x == 0 }, sourceCode: "{ let x = 0; return x == 0 }", comments: ["123"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a, "b", c: c)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a, "") }, sourceCode: ["": "a"], c: c, comments: ["b"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a(), "") }, sourceCode: ["": "a()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(b(__ec(c, "70")), "") }, sourceCode: ["": "b(c)", "70": "c"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b(__ec(c, "700")), "") }, sourceCode: ["": "a.b(c)", "6": "a", "700": "c"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(c, d: e))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b(__ec(c, "700"), d: __ec(e, "12100")), "") }, sourceCode: ["": "a.b(c, d: e)", "6": "a", "700": "c", "12100": "e"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(&c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b(&c), "") }, sourceCode: ["": "a.b(&c)", "6": "a"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(&c, &d.e))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b(&c, &d.e), "") }, sourceCode: ["": "a.b(&c, &d.e)", "6": "a"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(&c, d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b(&c, __ec(d, "18100")), "") }, sourceCode: ["": "a.b(&c, d)", "6": "a", "18100": "d"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(try c()))"##:
        ##"try Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a.self, "6").b(try __ec(c(), "1700")), "")) }, sourceCode: ["": "a.b(try c())", "6": "a", "1700": "c()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, "e")?.b(__ec(c, "1c00")), "") }, sourceCode: ["": "a?.b(c)", "e": "a", "1c00": "c"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a???.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, "3e")???.b(__ec(c, "1c000")), "") }, sourceCode: ["": "a???.b(c)", "3e": "a", "1c000": "c"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b.c(d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, "1e")?.b.c(__ec(d, "1c000")), "") }, sourceCode: ["": "a?.b.c(d)", "1e": "a", "1c000": "d"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect({}())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec({}(), "") }, sourceCode: ["": "{}()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(c: d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b(c: __ec(d, "1300")), "") }, sourceCode: ["": "a.b(c: d)", "6": "a", "1300": "d"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b { c })"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b { c }, "") }, sourceCode: ["": "a.b { c }", "6": "a"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a, sourceLocation: someValue)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a, "") }, sourceCode: ["": "a"], comments: [], isRequired: false, sourceLocation: someValue).__expected()"##,
      ##"#expect(a.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a.isB, "") }, sourceCode: ["": "a.isB"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a???.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, "1e")???.isB, "") }, sourceCode: ["": "a???.isB", "1e": "a"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, "e")?.b.isB, "") }, sourceCode: ["": "a?.b.isB", "e": "a"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b().isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(__ec(a, "1e")?.b(), "2")?.isB, "") }, sourceCode: ["": "a?.b().isB", "2": "a?.b()", "1e": "a"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(isolation: somewhere) {}"##:
        ##"Testing.__checkClosureCall(performing: {}, sourceCode: "{}", comments: [], isRequired: false, isolation: somewhere, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
    ]
  )
  func expectMacro(input: String, expectedOutput: String) throws {
    let (expectedOutput, _) = try parse(expectedOutput, removeWhitespace: true)
    let (actualOutput, _) = try parse(input, removeWhitespace: true)
    let (actualActual, _) = try parse(input)
    #expect(expectedOutput == actualOutput, "\(actualActual)")
  }

  @Test("#require() macro",
    arguments: [
      ##"#require(true)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(true, "")) }, sourceCode: ["": "true"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(false)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(false, "")) }, sourceCode: ["": "false"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(false, "Custom message")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(false, "")) }, sourceCode: ["": "false"], comments: ["Custom message"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(2 > 1)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(2 > 1, "")) }, sourceCode: ["": "2 > 1"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(((true || false) && true) || Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(((true || false) && true), "2") || __ec(__ec(Bool.self, "e000000").random(), "2000000"), "")) }, sourceCode: ["": "((true || false) && true) || Bool.random()", "2": "((true || false) && true)", "2000000": "Bool.random()", "e000000": "Bool"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(9 > 8 && 7 > 6, "Some comment")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(9 > 8, "2") && __ec(7 > 6, "400"), "")) }, sourceCode: ["": "9 > 8 && 7 > 6", "2": "9 > 8", "400": "7 > 6"], comments: ["Some comment"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require("a" == "b")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec.__cmp("a" , "2", "b", "200", { $0 == $1 }, "")) }, sourceCode: ["": #""a" == "b""#, "2": #""a""#, "200": #""b""#], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(!Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(!__ec(__ec(Bool.self, "1c").random(), "4"), "")) }, sourceCode: ["": "!Bool.random()", "4": "Bool.random()", "1c": "Bool"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require((true && false))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec((true && false), "")) }, sourceCode: ["": "(true && false)"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(try x())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(try __ec(x(), "4")) }, sourceCode: ["4": "x()"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(1 is Int)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec.__is(1 , __ec((Int).self, "10"), "10"), "")) }, sourceCode: ["": "1 is Int", "10": "Int"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require("123") { 1 == 2 } then: { foo() }"##:
        ##"Testing.__checkClosureCall(performing: { 1 == 2 }, then: { foo() }, sourceCode: "1 == 2", comments: ["123"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require("123") { let x = 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0 }, sourceCode: "let x = 0", comments: ["123"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require("123") { let x = 0; return x == 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0; return x == 0 }, sourceCode: "{ let x = 0; return x == 0 }", comments: ["123"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a, "b", c: c)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a, "")) }, sourceCode: ["": "a"], c: c, comments: ["b"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a(), "")) }, sourceCode: ["": "a()"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(b(__ec(c, "70")), "")) }, sourceCode: ["": "b(c)", "70": "c"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a.self, "6").b(__ec(c, "700")), "")) }, sourceCode: ["": "a.b(c)", "6": "a", "700": "c"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(c, d: e))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a.self, "6").b(__ec(c, "700"), d: __ec(e, "12100")), "")) }, sourceCode: ["": "a.b(c, d: e)", "6": "a", "700": "c", "12100": "e"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(&c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a.self, "6").b(&c), "")) }, sourceCode: ["": "a.b(&c)", "6": "a"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(&c, &d.e))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a.self, "6").b(&c, &d.e), "")) }, sourceCode: ["": "a.b(&c, &d.e)", "6": "a"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(&c, d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a.self, "6").b(&c, __ec(d, "18100")), "")) }, sourceCode: ["": "a.b(&c, d)", "6": "a", "18100": "d"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(try c()))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a.self, "6").b(try __ec(c(), "1700")), "")) }, sourceCode: ["": "a.b(try c())", "6": "a", "1700": "c()"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a?.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a, "e")?.b(__ec(c, "1c00")), "")) }, sourceCode: ["": "a?.b(c)", "e": "a", "1c00": "c"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a???.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a, "3e")???.b(__ec(c, "1c000")), "")) }, sourceCode: ["": "a???.b(c)", "3e": "a", "1c000": "c"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a?.b.c(d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a, "1e")?.b.c(__ec(d, "1c000")), "")) }, sourceCode: ["": "a?.b.c(d)", "1e": "a", "1c000": "d"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require({}())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec({}(), "")) }, sourceCode: ["": "{}()"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(c: d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a.self, "6").b(c: __ec(d, "1300")), "")) }, sourceCode: ["": "a.b(c: d)", "6": "a", "1300": "d"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b { c })"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a.self, "6").b { c }, "")) }, sourceCode: ["": "a.b { c }", "6": "a"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a, sourceLocation: someValue)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a, "")) }, sourceCode: ["": "a"], comments: [], isRequired: true, sourceLocation: someValue).__required()"##,
      ##"#require(a.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.isB, "")) }, sourceCode: ["": "a.isB"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a???.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a, "1e")???.isB, "")) }, sourceCode: ["": "a???.isB", "1e": "a"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a?.b.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a, "e")?.b.isB, "")) }, sourceCode: ["": "a?.b.isB", "e": "a"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a?.b().isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(__ec(a, "1e")?.b(), "2")?.isB, "")) }, sourceCode: ["": "a?.b().isB", "2": "a?.b()", "1e": "a"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(isolation: somewhere) {}"##:
        ##"Testing.__checkClosureCall(performing: {}, sourceCode: "{}", comments: [], isRequired: true, isolation: somewhere, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
    ]
  )
  func requireMacro(input: String, expectedOutput: String) throws {
    let (expectedOutput, _) = try parse(expectedOutput, removeWhitespace: true)
    let (actualOutput, _) = try parse(input, removeWhitespace: true)
    let (actualActual, _) = try parse(input)
    #expect(expectedOutput == actualOutput, "\(actualActual)")
  }

  @Test("Unwrapping #require() macro",
    arguments: [
      ##"#require(Optional<Int>.none)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(Optional<Int>.none, "")) }, sourceCode: ["": "Optional<Int>.none"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(nil ?? 123)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(nil ?? 123, "")) }, sourceCode: ["": "nil ?? 123"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(123 ?? nil)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(123 ?? nil, "")) }, sourceCode: ["": "123 ?? nil"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(123 as? Double)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec.__as(123 , __ec((Double).self, "20"), "20"), "")) }, sourceCode: ["": "123 as? Double", "20": "Double"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(123 as Double)"##:
        ##"Testing.__checkEscapedCondition(123 as Double, sourceCode: "123 as Double", comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(123 as! Double)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(123 as! Double, "")) }, sourceCode: ["": "123 as! Double"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
    ]
  )
  func unwrappingRequireMacro(input: String, expectedOutput: String) throws {
    let (expectedOutput, _) = try parse(expectedOutput, removeWhitespace: true)
    let (actualOutput, _) = try parse(input, removeWhitespace: true)
    let (actualActual, _) = try parse(input)
    #expect(expectedOutput == actualOutput, "\(actualActual)")
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
      try Testing.__checkCondition({  (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(try __ec(x(), "4")) }, sourceCode: ["4": "x()"], comments: [.__line("// Source comment"),.__documentationBlock("/** Doc comment */"),"Argument comment"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()
      """,

      """
      // Ignore me

      // Capture me
      #expect(try x())
      """:
      """
      // Ignore me

      // Capture me
      try Testing.__checkCondition({  (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(try __ec(x(), "4")) }, sourceCode: ["4": "x()"], comments: [.__line("// Capture me")], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()
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
      try Testing.__checkCondition({  (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(try __ec(x(), "4")) }, sourceCode: ["4": "x()"], comments: [.__line("// Capture me")], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()
      """,
    ]
  )
  func commentCapture(input: String, expectedOutput: String) throws {
    let (expectedOutput, _) = try parse(expectedOutput, removeWhitespace: true)
    let (actualOutput, _) = try parse(input, removeWhitespace: true)
    let (actualActual, _) = try parse(input)
    #expect(expectedOutput == actualOutput, "\(actualActual)")
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

  @Test("#require(Bool?) produces a diagnostic",
    arguments: [
      "#requireAmbiguous(expression)",
      "#requireAmbiguous((expression))",
      "#requireAmbiguous(a + b)",
      "#requireAmbiguous((a + b))",
      "#requireAmbiguous((a) + (b))",
    ]
  )
  func requireOptionalBoolProducesDiagnostic(input: String) throws {
    let (_, diagnostics) = try parse(input)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.diagMessage.severity == .warning)
    #expect(diagnostic.message.contains("is ambiguous"))
    #expect(diagnostic.fixIts.count == 2)
    #expect(diagnostic.fixIts[0].message.message.contains("as Bool?"))
    #expect(diagnostic.fixIts[1].message.message.contains("?? false"))
  }

  @Test("#require(as Bool?) suppresses its diagnostic",
    arguments: [
      "#requireAmbiguous(expression as Bool?)",
      "#requireAmbiguous((expression as Bool?))",
      "#requireAmbiguous((expression) as Bool?)",
      "#requireAmbiguous(a + b as Bool?)",
      "#requireAmbiguous((a + b) as Bool?)",
      "#requireAmbiguous((a) + (b) as Bool?)",
      "#requireAmbiguous(((a) + (b)) as Bool?)",
    ]
  )
  func requireOptionalBoolSuppressedWithExplicitType(input: String) throws {
    // Note we do not need to test "as Bool" (non-optional) because an
    // expression of type Bool rather than Bool? won't trigger the additional
    // diagnostics in the first place.
    let (_, diagnostics) = try parse(input)
    #expect(diagnostics.isEmpty)
  }

  @Test("#require(non-optional value) produces a diagnostic",
    arguments: [
      "#requireNonOptional(expression)",
    ]
  )
  func requireNonOptionalProducesDiagnostic(input: String) throws {
    let (_, diagnostics) = try parse(input)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.diagMessage.severity == .warning)
    #expect(diagnostic.message.contains("is redundant"))
  }

  @Test("#require(throws: Never.self) produces a diagnostic",
    arguments: [
      "#requireThrowsNever(throws: Never.self)",
    ]
  )
  func requireThrowsNeverProducesDiagnostic(input: String) throws {
    let (_, diagnostics) = try parse(input)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.diagMessage.severity == .warning)
    #expect(diagnostic.message.contains("is redundant"))
  }
}
