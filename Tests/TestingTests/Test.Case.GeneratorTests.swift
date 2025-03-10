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
      arguments: [1, 1, 1],
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
}
