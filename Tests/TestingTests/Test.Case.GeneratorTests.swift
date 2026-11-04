//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

@Suite("Test.Case.Generator Tests")
struct Test_Case_GeneratorTests {
  @Test func uniqueDiscriminators() throws {
    let generator = Test.Case.Generator(
      argumentList: __makeArgumentList([1, 1, 1]),
      parameters: [Test.Parameter(index: 0, firstName: "x", type: Int.self)],
      testFunction: { _ in }
    )

    let testCases = Array(generator)
    #expect(testCases.count == 3)

    let firstCase = try #require(testCases.first)
    #expect(firstCase.id.discriminator == 0)

    let discriminators = Set(testCases.map(\.id.discriminator))
    #expect(discriminators.count == 3)
  }

  @Test func cartesianProductSingleTupleParameter() throws {
    let generator = Test.Case.Generator(
      argumentLists: __makeArgumentList(["a", "b"]),
      __makeArgumentList([1, 2]),
      parameters: [Test.Parameter(index: 0, firstName: "pair", type: (String, Int).self)],
      testFunction: { (pair: (String, Int)) in }
    )

    let testCases = Array(generator)
    #expect(testCases.count == 4)

    for testCase in testCases {
      let arguments = try #require(testCase.arguments)
      #expect(arguments.count == 1)
      let argument = try #require(arguments.first)
      #expect(argument.parameter.firstName == "pair")
      #expect(argument.value is (String, Int))
    }

    let descriptions = testCases.compactMap { $0.arguments?.first?.testDescription }
    #expect(descriptions == ["(\"a\", 1)", "(\"a\", 2)", "(\"b\", 1)", "(\"b\", 2)"])

    let argumentIDs = Set(testCases.compactMap(\.id.argumentIDs))
    #expect(argumentIDs.count == 4)

    let discriminators = Set(testCases.compactMap(\.id.discriminator))
    #expect(discriminators == [0])
  }
}
