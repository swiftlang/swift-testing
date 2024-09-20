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
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(true, "true", [0]) }, comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(false)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(false, "false", [0]) }, comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(false, "Custom message")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in false }, sourceCode: [:], comments: ["Custom message"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(2 > 1)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(2 > 1, [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6]: "2 > 1"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(((true || false) && true) || Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec((__ec((__ec(true || false, [0, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16])) && true, [0, 4, 5, 6, 7, 9, 10, 11])) || __ec(Bool.random(), [0, 4, 5, 6, 31]), [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16]: "true || false", [0, 4, 5, 6, 7, 9, 10, 11]: "(true || false) && true", [0, 4, 5, 6, 31]: "Bool.random()", [0, 4, 5, 6]: "((true || false) && true) || Bool.random()"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(9 > 8 && 7 > 6, "Some comment")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(9 > 8, [0, 4, 5, 6, 7]) && __ec(7 > 6, [0, 4, 5, 6, 16]), [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6, 7]: "9 > 8", [0, 4, 5, 6, 16]: "7 > 6", [0, 4, 5, 6]: "9 > 8 && 7 > 6"], comments: ["Some comment"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("a" == "b")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec("a" == "b", [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6]: #""a" == "b""#], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(!Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(!__ec(Bool.random(), "Bool.random()", [0, 1]), "!Bool.random()", [0]) }, comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect((true && false))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in (__ec(true && false, [0, 4, 5, 6, 8, 9, 10])) }, sourceCode: [[0, 4, 5, 6, 8, 9, 10]: "true && false"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(try x())"##:
        ##"try Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(try __ec(x(), "x()", [0, 2])) }, comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(1 is Int)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec.__is(1 , __ec((Int).self, [0, 4, 5, 6, 10]), [0, 4, 5, 6, 10]), [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6, 10]: "Int", [0, 4, 5, 6]: "1 is Int"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("123") { 1 == 2 } then: { foo() }"##:
        ##"Testing.__checkClosureCall(performing: { 1 == 2 }, then: { foo() }, sourceCode: "1 == 2", comments: ["123"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("123") { let x = 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0 }, sourceCode: "let x = 0", comments: ["123"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect("123") { let x = 0; return x == 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0; return x == 0 }, sourceCode: "{ let x = 0; return x == 0 }", comments: ["123"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a, "b", c: c)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a, "a", [0]) }, c: c, comments: ["b"], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a(), "a()", [0]) }, comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(b(__ec(c, [0, 4, 5, 6, 10, 11, 12])), [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6, 10, 11, 12]: "c", [0, 4, 5, 6]: "b(c)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a.b(__ec(c, "c", [0, 3])), "a.b(c)", [0]) }, comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(c, d: e))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a.b(__ec(c, "c", [0, 3]), d: __ec(e, "e", [0, 4])), "a.b(c, d: e)", [0]) }, comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(&c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a.b(&c), [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6]: "a.b(&c)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(&c, &d.e))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a.b(&c, &d.e), [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6]: "a.b(&c, &d.e)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(&c, d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a.b(&c, __ec(d, "d", [0, 6])), "a.b(&c, d)", [0]) }, comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(try c()))"##:
        ##"try Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(try __ec(c(), [0, 4, 5, 6, 14, 15, 16, 18])), [0, 4, 5, 6])) }, sourceCode: [[0, 4, 5, 6, 14, 15, 16, 18]: "c()", [0, 4, 5, 6]: "a.b(try c())"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, [0, 4, 5, 6, 7, 8, 9])?.b(__ec(c, [0, 4, 5, 6, 16, 17, 18])), [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6, 7, 8, 9]: "a", [0, 4, 5, 6, 16, 17, 18]: "c", [0, 4, 5, 6]: "a?.b(c)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a???.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, [0, 4, 5, 6, 7, 8, 9, 10, 11])???.b(__ec(c, [0, 4, 5, 6, 20, 21, 22])), [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6, 7, 8, 9, 10, 11]: "a", [0, 4, 5, 6, 20, 21, 22]: "c", [0, 4, 5, 6]: "a???.b(c)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b.c(d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, [0, 4, 5, 6, 7, 8, 9, 10])?.b.c(__ec(d, [0, 4, 5, 6, 20, 21, 22])), [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6, 7, 8, 9, 10]: "a", [0, 4, 5, 6, 20, 21, 22]: "d", [0, 4, 5, 6]: "a?.b.c(d)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect({}())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec({}(), "{}()", [0]) }, comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b(c: d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a.b(c: __ec(d, [0, 4, 5, 6, 14, 15, 18])), [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6, 14, 15, 18]: "d", [0, 4, 5, 6]: "a.b(c: d)"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a.b { c })"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a.b { c }, [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6]: "a.b { c }"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a, sourceLocation: someValue)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(a, [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6]: "a"], comments: [], isRequired: false, sourceLocation: someValue).__expected()"##,
      ##"#expect(a.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in a.isB }, comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a???.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(a, [0, 4, 5, 6, 7, 8, 9, 10])???.isB, [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6, 7, 8, 9, 10]: "a", [0, 4, 5, 6]: "a???.isB"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in a?.b.isB }, comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
      ##"#expect(a?.b().isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in __ec(__ec(__ec(a, [0, 4, 5, 6, 7, 8, 9, 10])?.b(), [0, 4, 5, 6, 7])?.isB, [0, 4, 5, 6]) }, sourceCode: [[0, 4, 5, 6, 7, 8, 9, 10]: "a", [0, 4, 5, 6, 7]: "a?.b()", [0, 4, 5, 6]: "a?.b().isB"], comments: [], isRequired: false, sourceLocation: Testing.SourceLocation.__here()).__expected()"##,
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
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(true, "true", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(false)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(false, "false", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(false, "Custom message")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(false, "false", [0])) }, comments: ["Custom message"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(2 > 1)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(2, "2", [0, 1]) > __ec(1, "1", [0, 2]), "2 > 1", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(((true || false) && true) || Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec((__ec((__ec(__ec(true, "true", [0, 1, 3, 4, 5, 7, 8, 9]) || __ec(false, "false", [0, 1, 3, 4, 5, 7, 8, 10]), "true || false", [0, 1, 3, 4, 5, 7, 8])) && __ec(true, "true", [0, 1, 3, 4, 12]), "(true || false) && true", [0, 1, 3, 4])) || __ec(Bool.random(), "Bool.random()", [0, 14]), "((true || false) && true) || Bool.random()", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(9 > 8 && 7 > 6, "Some comment")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(9 > 8, [0, 4, 5, 6, 7]) && __ec(7 > 6, [0, 4, 5, 6, 16]), [0, 4, 5, 6])) }, sourceCode: [[0, 4, 5, 6, 7]: "9 > 8", [0, 4, 5, 6, 16]: "7 > 6", [0, 4, 5, 6]: "9 > 8 && 7 > 6"], comments: ["Some comment"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require("a" == "b")"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec("a", #""a""#, [0, 1]) == __ec("b", #""b""#, [0, 2]), #""a" == "b""#, [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(!Bool.random())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(!__ec(Bool.random(), "Bool.random()", [0, 1]), "!Bool.random()", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require((true && false))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry((__ec(__ec(true, "true", [0, 2, 3, 4]) && __ec(false, "false", [0, 2, 3, 5]), "true && false", [0, 2, 3]))) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(try x())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(try __ec(x(), "x()", [0, 2])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(1 is Int)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(1, "1", [0, 1]), #"__ec(1,"1",[0,1])"#, [0], is: (Int).self, "Int")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require("123") { 1 == 2 } then: { foo() }"##:
        ##"Testing.__checkClosureCall(performing: { 1 == 2 }, then: { foo() }, sourceCode: "1 == 2", comments: ["123"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require("123") { let x = 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0 }, sourceCode: "let x = 0", comments: ["123"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require("123") { let x = 0; return x == 0 }"##:
        ##"Testing.__checkClosureCall(performing: { let x = 0; return x == 0 }, sourceCode: "{ let x = 0; return x == 0 }", comments: ["123"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a, "b", c: c)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a, "a", [0])) }, c: c, comments: ["b"], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a(), "a()", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(b(__ec(c, "c", [0, 2])), "b(c)", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(__ec(c, "c", [0, 3])), "a.b(c)", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(c, d: e))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(__ec(c, "c", [0, 3]), d: __ec(e, "e", [0, 4])), "a.b(c, d: e)", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(&c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(&c), "a.b(&c)", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(&c, &d.e))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(&c, &d.e), "a.b(&c, &d.e)", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(&c, d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(&c, __ec(d, "d", [0, 6])), "a.b(&c, d)", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(try c()))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(try __ec(c(), "c()", [0, 3, 5])), "a.b(try c())", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a?.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a?.b(__ec(c, "c", [0, 5])), "a?.b(c)", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a???.b(c))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a???.b(__ec(c, "c", [0, 9])), "a???.b(c)", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a?.b.c(d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a?.b.c(__ec(d, "d", [0, 6])), "a?.b.c(d)", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require({}())"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec({}(), "{}()", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b(c: d))"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b(c: __ec(d, "d", [0, 3])), "a.b(c: d)", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a.b { c })"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a.b { c }, "a.b { c }", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a, sourceLocation: someValue)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a, [0, 4, 5, 6])) }, sourceCode: [[0, 4, 5, 6]: "a"], comments: [], isRequired: true, sourceLocation: someValue).__required()"##,
      ##"#require(a.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(a.isB) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a???.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(a???.isB) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a?.b.isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(a?.b.isB) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(a?.b().isB)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(a?.b(), "a?.b()", [0, 1]).isB) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
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
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(nil ?? __ec(123, "123", [0, 3]), "nil ?? 123", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(123 ?? nil)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(123, "123", [0, 1]) ?? nil, "123 ?? nil", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(123 as? Double)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(__ec(123, "123", [0, 1]), #"__ec(123,"123",[0,1])"#, [0], as: (Double).self, "Double")) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(123 as Double)"##:
        ##"Testing.__checkEscapedCondition(123 as Double, sourceCode: "123 as Double", comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
      ##"#require(123 as! Double)"##:
        ##"Testing.__checkCondition({ (__ec: inout Testing.__ExpectationContext) in try Testing.__requiringTry(__ec(123 as! Double, "123 as! Double", [0])) }, comments: [], isRequired: true, sourceLocation: Testing.SourceLocation.__here()).__required()"##,
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
