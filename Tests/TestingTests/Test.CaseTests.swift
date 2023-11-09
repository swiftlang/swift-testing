//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ExperimentalParameterizedTesting) import Testing

@Suite("Test.Case Tests")
struct Test_CaseTests {
  @Suite("arguments(pairedWith:)")
  struct ArgumentsPairedWith {
    @Test("Single parameter")
    func singleParameter() throws {
      let testCase = Test.Case(arguments: ["value"]) {}
      let pairedArguments = Array(testCase.arguments(pairedWith: [Test.ParameterInfo(firstName: "foo")]))
      #expect(pairedArguments.count == 1)

      let (parameter, opaqueArgument) = try #require(pairedArguments.first)
      #expect(parameter.firstName == "foo")
      let argument = try #require(opaqueArgument as? String)
      #expect(argument == "value")
    }

    @Test("Two parameters")
    func twoParameters() throws {
      let testCase = Test.Case(arguments: [
        "value",
        123,
      ]) {}
      let pairedArguments = Array(testCase.arguments(pairedWith: [
        Test.ParameterInfo(firstName: "foo"),
        Test.ParameterInfo(firstName: "bar"),
      ]))
      #expect(pairedArguments.count == 2)

      do {
        let (parameter, opaqueArgument) = try #require(pairedArguments.first)
        #expect(parameter.firstName == "foo")
        let argument = try #require(opaqueArgument as? String)
        #expect(argument == "value")
      }
      do {
        let (parameter, opaqueArgument) = try #require(pairedArguments.last)
        #expect(parameter.firstName == "bar")
        let argument = try #require(opaqueArgument as? Int)
        #expect(argument == 123)
      }
    }

    @Test("One-value tuple parameter")
    func oneValueTupleParameter() throws {
      let testCase = Test.Case(arguments: [("value")]) {}
      let pairedArguments = Array(testCase.arguments(pairedWith: [Test.ParameterInfo(firstName: "foo")]))
      #expect(pairedArguments.count == 1)

      let (parameter, opaqueArgument) = try #require(pairedArguments.first)
      #expect(parameter.firstName == "foo")
      let argument = try #require(opaqueArgument as? String)
      #expect(argument == "value")
    }

    @Test("Two-value tuple parameter")
    func twoValueTupleParameter() throws {
      let testCase = Test.Case(arguments: [("value", 123)]) {}
      let pairedArguments = Array(testCase.arguments(pairedWith: [
        Test.ParameterInfo(firstName: "foo"),
        Test.ParameterInfo(firstName: "bar"),
      ]))
      #expect(pairedArguments.count == 2)

      do {
        let (parameter, opaqueArgument) = try #require(pairedArguments.first)
        #expect(parameter.firstName == "foo")
        let argument = try #require(opaqueArgument as? String)
        #expect(argument == "value")
      }
      do {
        let (parameter, opaqueArgument) = try #require(pairedArguments.last)
        #expect(parameter.firstName == "bar")
        let argument = try #require(opaqueArgument as? Int)
        #expect(argument == 123)
      }
    }
  }
}
