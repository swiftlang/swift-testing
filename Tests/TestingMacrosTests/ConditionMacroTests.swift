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
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[true, 0x0] }, sourceCode: [0x0: "true"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(false)"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[false, 0x0] }, sourceCode: [0x0: "false"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(false, "Custom message")"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[false, 0x0] }, sourceCode: [0x0: "false"], comments: ["Custom message"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(2 > 1)"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[2 > 1, 0x0] }, sourceCode: [0x0: "2 > 1"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(((true || false) && true) || Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[(__ec[__ec[(__ec[__ec[true, 0xf7a] || __ec[false, 0x877a], 0x77a]), 0x7a] && __ec[true, 0x10003a], 0x3a]), 0x2] || __ec[Bool.random(), 0x2000000], 0x0] }, sourceCode: [0x0: "((true || false) && true) || Bool.random()", 0x2: "((true || false) && true)", 0x3a: "(true || false) && true", 0x7a: "(true || false)", 0x77a: "true || false", 0xf7a: "true", 0x877a: "false", 0x10003a: "true", 0x2000000: "Bool.random()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(9 > 8 && 7 > 6, "Some comment")"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[9 > 8, 0x2] && __ec[7 > 6, 0x400], 0x0] }, sourceCode: [0x0: "9 > 8 && 7 > 6", 0x2: "9 > 8", 0x400: "7 > 6"], comments: ["Some comment"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("a" == "b")"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec.__cmp({ lhs, rhs -> Swift.Bool in lhs == rhs }, 0x0, "a", 0x2, "b", 0x200) }, sourceCode: [0x0: #""a" == "b""#], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(!Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[!Bool.random(), 0x0] }, sourceCode: [0x0: "!Bool.random()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect((true && false))"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[(__ec[__ec[true, 0x3c] && __ec[false, 0x21c], 0x1c]), 0x0] }, sourceCode: [0x0: "(true && false)", 0x1c: "true && false", 0x3c: "true", 0x21c: "false"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(try x())"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try __ec[x(), 0x4] }, sourceCode: [0x4: "x()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(1 is Int)"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec.__is(1, 0x0, (Int).self, 0x10) }, sourceCode: [0x0: "1 is Int", 0x10: "Int"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("123") { 1 == 2 } then: { foo() }"##:
        ##"Testing.__checkClosureCall(performing: { 1 == 2 }, then: { foo() }, sourceCode: [0x0: "1 == 2"], comments: ["123"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("123") { let x = 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0 }, sourceCode: [0x0: "let x = 0"], comments: ["123"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("123") { let x = 0; return x == 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0; return x == 0 }, sourceCode: [0x0: "{ let x = 0; return x == 0 }"], comments: ["123"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a, "b", c: c)"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[a, 0x0] }, sourceCode: [0x0: "a"], c: c, comments: ["b"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a())"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[a(), 0x0] }, sourceCode: [0x0: "a()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(b(c))"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[b(__ec[c, 0x70]), 0x0] }, sourceCode: [0x0: "b(c)", 0x70: "c"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[a.self, 0x6].b(__ec[c, 0x700]), 0x0] }, sourceCode: [0x0: "a.b(c)", 0x6: "a", 0x700: "c"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(c, d: e))"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[a.self, 0x6].b(__ec[c, 0x700], d: __ec[e, 0x12100]), 0x0] }, sourceCode: [0x0: "a.b(c, d: e)", 0x6: "a", 0x700: "c", 0x12100: "e"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(&c))"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in defer { __ec.__inoutAfter(c, 0x1700) } return __ec[__ec[a.self, 0x6].b(&c), 0x0] }, sourceCode: [0x0: "a.b(&c)", 0x6: "a", 0x1700: "c"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(&c, &d.e))"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in defer { __ec.__inoutAfter(c, 0x1700) __ec.__inoutAfter(d.e, 0x58100) } return __ec[__ec[a.self, 0x6].b(&c, &d.e), 0x0] }, sourceCode: [0x0: "a.b(&c, &d.e)", 0x6: "a", 0x1700: "c", 0x58100: "d.e"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(&c, d))"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in defer { __ec.__inoutAfter(c, 0x1700) } return __ec[__ec[a.self, 0x6].b(&c, __ec[d, 0x18100]), 0x0] }, sourceCode: [0x0: "a.b(&c, d)", 0x6: "a", 0x1700: "c", 0x18100: "d"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(try c()))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[a.self, 0x6].b(try __ec[c(), 0x1700]), 0x0]) }, sourceCode: [0x0: "a.b(try c())", 0x6: "a", 0x1700: "c()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[a, 0xe]?.b(__ec[c, 0x1c00]), 0x0] }, sourceCode: [0x0: "a?.b(c)", 0xe: "a", 0x1c00: "c"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a???.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[a, 0x3e]???.b(__ec[c, 0x1c000]), 0x0] }, sourceCode: [0x0: "a???.b(c)", 0x3e: "a", 0x1c000: "c"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b.c(d))"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[a, 0x1e]?.b.c(__ec[d, 0x1c000]), 0x0] }, sourceCode: [0x0: "a?.b.c(d)", 0x1e: "a", 0x1c000: "d"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect({}())"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[{}(), 0x0] }, sourceCode: [0x0: "{}()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(c: d))"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[a.self, 0x6].b(c: __ec[d, 0x1300]), 0x0] }, sourceCode: [0x0: "a.b(c: d)", 0x6: "a", 0x1300: "d"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b { c })"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[a.self, 0x6].b { c }, 0x0] }, sourceCode: [0x0: "a.b { c }", 0x6: "a"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a, sourceLocation: someValue)"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[a, 0x0] }, sourceCode: [0x0: "a"], comments: [], isRequired: false, sourceLocation: someValue).__expected()"##,
      ##"#expect(a.isB)"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[a.isB, 0x0] }, sourceCode: [0x0: "a.isB"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a???.isB)"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[a, 0x1e]???.isB, 0x0] }, sourceCode: [0x0: "a???.isB", 0x1e: "a"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b.isB)"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[a, 0xe]?.b.isB, 0x0] }, sourceCode: [0x0: "a?.b.isB", 0xe: "a"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b().isB)"##:
        ##"Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[__ec[a, 0x1e]?.b(), 0x2]?.isB, 0x0] }, sourceCode: [0x0: "a?.b().isB", 0x2: "a?.b()", 0x1e: "a"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(isolation: somewhere) {}"##:
        ##"Testing.__checkClosureCall(performing: {}, sourceCode: [0x0: "{}"], comments: [], isRequired: false, isolation: somewhere, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
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
      ##"try #require(true)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[true, 0x0]) }, sourceCode: [0x0: "true"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(false)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[false, 0x0]) }, sourceCode: [0x0: "false"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(false, "Custom message")"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[false, 0x0]) }, sourceCode: [0x0: "false"], comments: ["Custom message"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(2 > 1)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[2 > 1, 0x0]) }, sourceCode: [0x0: "2 > 1"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(((true || false) && true) || Bool.random())"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[(__ec[__ec[(__ec[__ec[true, 0xf7a] || __ec[false, 0x877a], 0x77a]), 0x7a] && __ec[true, 0x10003a], 0x3a]), 0x2] || __ec[Bool.random(), 0x2000000], 0x0]) }, sourceCode: [0x0: "((true || false) && true) || Bool.random()", 0x2: "((true || false) && true)", 0x3a: "(true || false) && true", 0x7a: "(true || false)", 0x77a: "true || false", 0xf7a: "true", 0x877a: "false", 0x10003a: "true", 0x2000000: "Bool.random()"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(9 > 8 && 7 > 6, "Some comment")"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[9 > 8, 0x2] && __ec[7 > 6, 0x400], 0x0]) }, sourceCode: [0x0: "9 > 8 && 7 > 6", 0x2: "9 > 8", 0x400: "7 > 6"], comments: ["Some comment"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require("a" == "b")"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec.__cmp({ lhs, rhs -> Swift.Bool in lhs == rhs }, 0x0, "a", 0x2, "b", 0x200)) }, sourceCode: [0x0: #""a" == "b""#], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(!Bool.random())"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[!Bool.random(), 0x0]) }, sourceCode: [0x0: "!Bool.random()"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require((true && false))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[(__ec[__ec[true, 0x3c] && __ec[false, 0x21c], 0x1c]), 0x0]) }, sourceCode: [0x0: "(true && false)", 0x1c: "true && false", 0x3c: "true", 0x21c: "false"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(try x())"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try __ec[x(), 0x4] }, sourceCode: [0x4: "x()"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(1 is Int)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec.__is(1, 0x0, (Int).self, 0x10)) }, sourceCode: [0x0: "1 is Int", 0x10: "Int"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require("123") { 1 == 2 } then: { foo() }"##:
        ##"try Testing.__checkClosureCall(performing: { 1 == 2 }, then: { foo() }, sourceCode: [0x0: "1 == 2"], comments: ["123"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require("123") { let x = 0 }"##:
        ##"try Testing.__checkClosureCall(performing: { let x = 0 }, sourceCode: [0x0: "let x = 0"], comments: ["123"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require("123") { let x = 0; return x == 0 }"##:
        ##"try Testing.__checkClosureCall(performing: { let x = 0; return x == 0 }, sourceCode: [0x0: "{ let x = 0; return x == 0 }"], comments: ["123"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a, "b", c: c)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[a, 0x0]) }, sourceCode: [0x0: "a"], c: c, comments: ["b"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a())"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[a(), 0x0]) }, sourceCode: [0x0: "a()"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(b(c))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[b(__ec[c, 0x70]), 0x0]) }, sourceCode: [0x0: "b(c)", 0x70: "c"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a.b(c))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[a.self, 0x6].b(__ec[c, 0x700]), 0x0]) }, sourceCode: [0x0: "a.b(c)", 0x6: "a", 0x700: "c"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a.b(c, d: e))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[a.self, 0x6].b(__ec[c, 0x700], d: __ec[e, 0x12100]), 0x0]) }, sourceCode: [0x0: "a.b(c, d: e)", 0x6: "a", 0x700: "c", 0x12100: "e"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a.b(&c))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in defer { __ec.__inoutAfter(c, 0x1700) } return try Testing.__requiringTry(__ec[__ec[a.self, 0x6].b(&c), 0x0]) }, sourceCode: [0x0: "a.b(&c)", 0x6: "a", 0x1700: "c"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a.b(&c, &d.e))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in defer { __ec.__inoutAfter(c, 0x1700) __ec.__inoutAfter(d.e, 0x58100) } return try Testing.__requiringTry(__ec[__ec[a.self, 0x6].b(&c, &d.e), 0x0]) }, sourceCode: [0x0: "a.b(&c, &d.e)", 0x6: "a", 0x1700: "c", 0x58100: "d.e"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a.b(&c, d))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in defer { __ec.__inoutAfter(c, 0x1700) } return try Testing.__requiringTry(__ec[__ec[a.self, 0x6].b(&c, __ec[d, 0x18100]), 0x0]) }, sourceCode: [0x0: "a.b(&c, d)", 0x6: "a", 0x1700: "c", 0x18100: "d"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a.b(try c()))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[a.self, 0x6].b(try __ec[c(), 0x1700]), 0x0]) }, sourceCode: [0x0: "a.b(try c())", 0x6: "a", 0x1700: "c()"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a?.b(c))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[a, 0xe]?.b(__ec[c, 0x1c00]), 0x0]) }, sourceCode: [0x0: "a?.b(c)", 0xe: "a", 0x1c00: "c"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a???.b(c))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[a, 0x3e]???.b(__ec[c, 0x1c000]), 0x0]) }, sourceCode: [0x0: "a???.b(c)", 0x3e: "a", 0x1c000: "c"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a?.b.c(d))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[a, 0x1e]?.b.c(__ec[d, 0x1c000]), 0x0]) }, sourceCode: [0x0: "a?.b.c(d)", 0x1e: "a", 0x1c000: "d"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require({}())"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[{}(), 0x0]) }, sourceCode: [0x0: "{}()"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a.b(c: d))"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[a.self, 0x6].b(c: __ec[d, 0x1300]), 0x0]) }, sourceCode: [0x0: "a.b(c: d)", 0x6: "a", 0x1300: "d"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a.b { c })"##:
                   ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[a.self, 0x6].b { c }, 0x0]) }, sourceCode: [0x0: "a.b { c }", 0x6: "a"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a, sourceLocation: someValue)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[a, 0x0]) }, sourceCode: [0x0: "a"], comments: [], isRequired: true, sourceLocation: someValue).__required()"##,
      ##"try #require(a.isB)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[a.isB, 0x0]) }, sourceCode: [0x0: "a.isB"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a???.isB)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[a, 0x1e]???.isB, 0x0]) }, sourceCode: [0x0: "a???.isB", 0x1e: "a"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a?.b.isB)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[a, 0xe]?.b.isB, 0x0]) }, sourceCode: [0x0: "a?.b.isB", 0xe: "a"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(a?.b().isB)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[__ec[__ec[a, 0x1e]?.b(), 0x2]?.isB, 0x0]) }, sourceCode: [0x0: "a?.b().isB", 0x2: "a?.b()", 0x1e: "a"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #require(isolation: somewhere) {}"##:
        ##"try Testing.__checkClosureCall(performing: {}, sourceCode: [0x0: "{}"], comments: [], isRequired: true, isolation: somewhere, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
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
      ##"try #requireUnwrap(Optional<Int>.none)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Optional>) -> Swift.Optional in try Testing.__requiringTry(__ec[Optional<Int>.none, 0x0]) }, sourceCode: [0x0: "Optional<Int>.none"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #requireUnwrap(nil ?? 123)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Optional>) -> Swift.Optional in try Testing.__requiringTry(__ec[nil ?? 123, 0x0]) }, sourceCode: [0x0: "nil ?? 123"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #requireUnwrap(123 ?? nil)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Optional>) -> Swift.Optional in try Testing.__requiringTry(__ec[123 ?? nil, 0x0]) }, sourceCode: [0x0: "123 ?? nil"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #requireUnwrap(123 as? Double)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Optional>) -> Swift.Optional in try Testing.__requiringTry(__ec.__as(123, 0x0, (Double).self, 0x20)) }, sourceCode: [0x0: "123 as? Double", 0x20: "Double"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #requireUnwrap(123 as Double)"##:
        ##"try Testing.__checkEscapedCondition(123 as Double, sourceCode: [0x0: "123 as Double"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"try #requireUnwrap(123 as! Double)"##:
        ##"try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Optional>) -> Swift.Optional in try Testing.__requiringTry(__ec[123 as! Double, 0x0]) }, sourceCode: [0x0: "123 as! Double"], comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
    ]
  )
  func unwrappingRequireMacro(input: String, expectedOutput: String) throws {
    let (expectedOutput, _) = try parse(expectedOutput, removeWhitespace: true)
    let (actualOutput, _) = try parse(input, removeWhitespace: true)
    let (actualActual, _) = try parse(input)
    #expect(expectedOutput == actualOutput, "\(actualActual)")
  }

  @Test("Deep expression IDs", arguments: [
    ##"#expect(a(b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q))"##:
      ##"__ec[q, Testing.__ExpressionID(66, 65, 4)]"##,
  ]) func deepExpressionID(input: String, expectedOutput: String) throws {
    let (expectedOutput, _) = try parse(expectedOutput, removeWhitespace: true)
    let (actualOutput, _) = try parse(input, removeWhitespace: true)
    let (actualActual, _) = try parse(input)
    #expect(actualOutput.contains(expectedOutput), "\(actualActual)")
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
      try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try __ec[x(), 0x4] }, sourceCode: [0x4: "x()"], comments: [.__line("// Source comment"),.__documentationBlock("/** Doc comment */"),"Argument comment"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()
      """,

      """
      // Ignore me

      // Capture me
      #expect(try x())
      """:
      """
      // Ignore me

      // Capture me
      try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try __ec[x(), 0x4] }, sourceCode: [0x4: "x()"], comments: [.__line("// Capture me")], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()
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
      try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try __ec[x(), 0x4] }, sourceCode: [0x4: "x()"], comments: [.__line("// Capture me")], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()
      """,

      """
      // Capture me
      try #expect(x)
      """:
      """
      // Capture me
      try Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try Testing.__requiringTry(__ec[x, 0x0]) }, sourceCode: [0x0: "x"], comments: [.__line("// Capture me")], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()
      """,

      """
      // Capture me
      await #expect(x)
      """:
      """
      // Capture me
      await Testing.__checkConditionAsync({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in await Testing.__requiringAwait(__ec[x, 0x0]) }, sourceCode: [0x0: "x"], comments: [.__line("// Capture me")], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()

      """,

      """
      // Ignore me

      // Comment for try
      try
      // Comment for await
      await
      // Comment for expect
      #expect(x)
      """:
      """
      // Comment for try
      try
      // Comment for await
      await
      // Comment for expect
      Testing.__checkConditionAsync({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in try await Testing.__requiringTry(Testing.__requiringAwait(__ec[x, 0x0])) }, sourceCode: [0x0: "x"], comments: [.__line("// Comment for try"), .__line("// Comment for await"), .__line("// Comment for expect")], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()
      """,

      """
      // Ignore me
      func example() {
        // Capture me
        #expect(x())
      }
      """:
      """
      func example() {
        // Capture me
        Testing.__checkCondition({ (__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[x(), 0x0] }, sourceCode: [0x0: "x()"], comments: [.__line("// Capture me")], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()
      }
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

#if !SWT_FIXED_137943258
  @Test(
    "#require(optional value mistyped as non-optional) diagnostic is suppressed",
    .bug("https://github.com/swiftlang/swift/issues/79202"),
    arguments: [
      "#requireNonOptional(expression as? T)",
      "#requireNonOptional(expression as Optional<T>)",
      "#requireNonOptional(expression ?? nil)",
    ]
  )
  func requireNonOptionalDiagnosticSuppressed(input: String) throws {
    let (_, diagnostics) = try parse(input)
    #expect(diagnostics.isEmpty)
  }
#endif

  @Test("#require(throws: Never.self) produces a diagnostic",
    arguments: [
      "#requireThrows(throws: Swift.Never.self)",
      "#requireThrows(throws: Never.self)",
      "#requireThrowsNever(throws: Never.self)",
    ]
  )
  func requireThrowsNeverProducesDiagnostic(input: String) throws {
    let (_, diagnostics) = try parse(input)

    let diagnostic = try #require(diagnostics.first)
    #expect(diagnostic.diagMessage.severity == .warning)
    #expect(diagnostic.message.contains("is redundant"))
  }

  @Test("#expect(processExitsWith:) diagnostics",
    arguments: [
      "func f<T>() { #expectExitTest(processExitsWith: x) {} }":
        "Cannot call macro ''#expectExitTest(processExitsWith:_:)'' within generic function 'f()'",
    ]
  )
  func exitTestDiagnostics(input: String, expectedMessage: String) throws {
    let (_, diagnostics) = try parse(input)

    #expect(diagnostics.count > 0)
    for diagnostic in diagnostics {
      #expect(diagnostic.diagMessage.severity == .error)
      #expect(diagnostic.message == expectedMessage)
    }
  }

  @Test("#expect(processExitsWith:) produces a diagnostic for a bad capture",
        arguments: [
          "#expectExitTest(processExitsWith: x) { [weak a] in }":
            "Specifier 'weak' cannot be used with captured value 'a'",
          "#expectExitTest(processExitsWith: x) { [a] in }":
            "Type of captured value 'a' is ambiguous",
          "#expectExitTest(processExitsWith: x) { [a = b] in }":
            "Type of captured value 'a' is ambiguous",
          "#expectExitTest(processExitsWith: x) { [a = b as any T] in }":
            "Type of captured value 'a' is ambiguous",
          "#expectExitTest(processExitsWith: x) { [a = b as some T] in }":
            "Type of captured value 'a' is ambiguous",
          "struct S<T> { func f() { #expectExitTest(processExitsWith: x) { [a] in } } }":
            "Cannot call macro ''#expectExitTest(processExitsWith:_:)'' within generic structure 'S'",
        ]
  )
  func exitTestCaptureDiagnostics(input: String, expectedMessage: String) throws {
    let (_, diagnostics) = try parse(input)

    #expect(diagnostics.count > 0)
    for diagnostic in diagnostics {
      #expect(diagnostic.diagMessage.severity == .error)
      #expect(diagnostic.message == expectedMessage)
    }
  }
}
