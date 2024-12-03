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
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(((true || false) && true), "2") || __ec(__ec(Bool.self, "e000000").random(), "2000000"), "") }, sourceCode: ["2": "((true || false) && true)", "e000000": "Bool", "2000000": "Bool.random()", "": "((true || false) && true) || Bool.random()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(9 > 8 && 7 > 6, "Some comment")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(9 > 8, "2") && __ec(7 > 6, "400"), "") }, sourceCode: ["2": "9 > 8", "400": "7 > 6", "": "9 > 8 && 7 > 6"], comments: ["Some comment"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("a" == "b")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec("a" == "b", "") }, sourceCode: ["": #""a" == "b""#], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(!Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(!__ec(__ec(Bool.self, "1c").random(), "4"), "") }, sourceCode: ["1c": "Bool", "4": "Bool.random()", "": "!Bool.random()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect((true && false))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec((true && false), "") }, sourceCode: ["": "(true && false)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(try x())"##:
        ##"try Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(try __ec(x(), "4")) }, sourceCode: ["4": "x()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(1 is Int)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec.__is(1 , __ec((Int).self, "10"), "10"), "") }, sourceCode: ["10": "Int", "": "1 is Int"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
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
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(b(__ec(c, "70")), "") }, sourceCode: ["70": "c", "": "b(c)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b(__ec(c, "700")), "") }, sourceCode: ["6": "a", "700": "c", "": "a.b(c)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(c, d: e))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b(__ec(c, "700"), d: __ec(e, "12100")), "") }, sourceCode: ["6": "a", "700": "c", "12100": "e", "": "a.b(c, d: e)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(&c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b(&c), "") }, sourceCode: ["6": "a", "": "a.b(&c)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(&c, &d.e))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b(&c, &d.e), "") }, sourceCode: ["6": "a", "": "a.b(&c, &d.e)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(&c, d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b(&c, __ec(d, "18100")), "") }, sourceCode: ["6": "a", "18100": "d", "": "a.b(&c, d)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(try c()))"##:
        ##"try Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(a.self, "6").b(try __ec(c(), "1700")), "")) }, sourceCode: ["6": "a", "1700": "c()", "": "a.b(try c())"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, "e")?.b(__ec(c, "1c00")), "") }, sourceCode: ["e": "a", "1c00": "c", "": "a?.b(c)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a???.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, "3e")???.b(__ec(c, "1c000")), "") }, sourceCode: ["3e": "a", "1c000": "c", "": "a???.b(c)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b.c(d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, "1e")?.b.c(__ec(d, "1c000")), "") }, sourceCode: ["1e": "a", "1c000": "d", "": "a?.b.c(d)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect({}())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec({}(), "") }, sourceCode: ["": "{}()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(c: d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b(c: __ec(d, "1300")), "") }, sourceCode: ["6": "a", "1300": "d", "": "a.b(c: d)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b { c })"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a.self, "6").b { c }, "") }, sourceCode: ["6": "a", "": "a.b { c }"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a, sourceLocation: someValue)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a, "") }, sourceCode: ["": "a"], comments: [], isRequired: false, sourceLocation: someValue).__expected()"##,
      ##"#expect(a.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a.isB, "") }, sourceCode: ["": "a.isB"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a???.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, "1e")???.isB, "") }, sourceCode: ["1e": "a", "": "a???.isB"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, "e")?.b.isB, "") }, sourceCode: ["e": "a", "": "a?.b.isB"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b().isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(__ec(a, "1e")?.b(), "2")?.isB, "") }, sourceCode: ["1e": "a", "2": "a?.b()", "": "a?.b().isB"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
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
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(true, "true", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(false)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(false, "false", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(false, "Custom message")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(false, "false", "")) }, comments: ["Custom message"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(2 > 1)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(2, "2", "1c") > __ec(1, "1", [0, 2]), "2 > 1", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(((true || false) && true) || Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec((__ec((__ec(__ec(true, "true", [0, 1, 3, 4, 5, 7, 8, 9]) || __ec(false, "false", [0, 1, 3, 4, 5, 7, 8, 10]), "true || false", [0, 1, 3, 4, 5, 7, 8])) && __ec(true, "true", [0, 1, 3, 4, 12]), "(true || false) && true", [0, 1, 3, 4])) || __ec(Bool.random(), "Bool.random()", [0, 14]), "((true || false) && true) || Bool.random()", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(9 > 8 && 7 > 6, "Some comment")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(9 > 8, [0, 4, 5, 6, 7]) && __ec(7 > 6, [0, 4, 5, 6, 16]), [0, 4, 5, 6])) }, sourceCode: [[0, 4, 5, 6, 7]: "9 > 8", [0, 4, 5, 6, 16]: "7 > 6", [0, 4, 5, 6]: "9 > 8 && 7 > 6"], comments: ["Some comment"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require("a" == "b")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec("a", #""a""#, "1c") == __ec("b", #""b""#, [0, 2]), #""a" == "b""#, "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(!Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(!__ec(Bool.random(), "Bool.random()", "1c"), "!Bool.random()", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require((true && false))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry((__ec(__ec(true, "true", [0, 2, 3, 4]) && __ec(false, "false", [0, 2, 3, 5]), "true && false", [0, 2, 3]))) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(try x())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(try __ec(x(), "x()", [0, 2])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(1 is Int)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(1, "1", "1c"), #"__ec(1,"1",[0,1])"#, "", is: (Int).self, "Int")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require("123") { 1 == 2 } then: { foo() }"##:
        ##"Testing.__checkClosureCall(performing: { 1 == 2 }, then: { foo() }, sourceCode: "1 == 2", comments: ["123"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require("123") { let x = 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0 }, sourceCode: "let x = 0", comments: ["123"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require("123") { let x = 0; return x == 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0; return x == 0 }, sourceCode: "{ let x = 0; return x == 0 }", comments: ["123"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a, "b", c: c)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a, "a", "")) }, c: c, comments: ["b"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a(), "a()", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(b(__ec(c, "c", [0, 2])), "b(c)", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(__ec(c, "c", [0, 3])), "a.b(c)", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(c, d: e))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(__ec(c, "c", [0, 3]), d: __ec(e, "e", [0, 4])), "a.b(c, d: e)", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(&c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(&c), "a.b(&c)", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(&c, &d.e))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(&c, &d.e), "a.b(&c, &d.e)", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(&c, d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(&c, __ec(d, "d", [0, 6])), "a.b(&c, d)", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(try c()))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(try __ec(c(), "c()", [0, 3, 5])), "a.b(try c())", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a?.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a?.b(__ec(c, "c", [0, 5])), "a?.b(c)", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a???.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a???.b(__ec(c, "c", [0, 9])), "a???.b(c)", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a?.b.c(d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a?.b.c(__ec(d, "d", [0, 6])), "a?.b.c(d)", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require({}())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec({}(), "{}()", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(c: d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(c: __ec(d, "d", [0, 3])), "a.b(c: d)", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b { c })"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b { c }, "a.b { c }", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a, sourceLocation: someValue)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a, [0, 4, 5, 6])) }, sourceCode: [[0, 4, 5, 6]: "a"], comments: [], isRequired: true, sourceLocation: someValue).__required()"##,
      ##"#require(a.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(a.isB) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a???.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(a???.isB) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a?.b.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(a?.b.isB) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a?.b().isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a?.b(), "a?.b()", "1c").isB) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
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
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(Optional<Int>.none) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(nil ?? 123)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(nil ?? __ec(123, "123", [0, 3]), "nil ?? 123", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(123 ?? nil)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(123, "123", "1c") ?? nil, "123 ?? nil", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(123 as? Double)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(123, "123", "1c"), #"__ec(123,"123",[0,1])"#, "", as: (Double).self, "Double")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(123 as Double)"##:
        ##"Testing.__checkEscapedCondition(123 as Double, sourceCode: "123 as Double", comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(123 as! Double)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(123 as! Double, "123 as! Double", "")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
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
      try Testing.__checkCondition({  (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(try __ec(x(), "x()", [0, 2])) }, comments: [.__line("// Source comment"),.__documentationBlock("/** Doc comment */"),"Argument comment"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()
      """,

      """
      // Ignore me

      // Capture me
      #expect(try x())
      """:
      """
      // Ignore me

      // Capture me
      try Testing.__checkCondition({  (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(try __ec(x(), "x()", [0, 2])) }, comments: [.__line("// Capture me")], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()
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
      try Testing.__checkCondition({  (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(try __ec(x(), "x()", [0, 2])) }, comments: [.__line("// Capture me")], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()
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
