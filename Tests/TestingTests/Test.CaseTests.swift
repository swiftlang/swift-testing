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

@Suite("Test.Case Tests")
struct Test_CaseTests {
  @Test func singleStableArgument() throws {
    let testCase = Test.Case(
      values: [1],
      parameters: [Test.Parameter(index: 0, firstName: "x", type: Int.self)],
      body: {}
    )
    #expect(testCase.id.isStable)
    let arguments = try #require(testCase.arguments)
    #expect(arguments.allSatisfy { $0.id.isStable })
  }

  @Test func twoStableArguments() throws {
    let testCase = Test.Case(
      values: [1, "a"],
      parameters: [
        Test.Parameter(index: 0, firstName: "x", type: Int.self),
        Test.Parameter(index: 1, firstName: "y", type: String.self),
      ],
      body: {}
    )
    #expect(testCase.id.isStable)
    let arguments = try #require(testCase.arguments)
    #expect(arguments.allSatisfy { $0.id.isStable })
  }

  @Test("Two arguments: one non-stable, followed by one stable")
  func nonStableAndStableArgument() throws {
    let testCase = Test.Case(
      values: [NonCodable(), IssueRecordingEncodable()],
      parameters: [
        Test.Parameter(index: 0, firstName: "x", type: NonCodable.self),
        Test.Parameter(index: 1, firstName: "y", type: IssueRecordingEncodable.self),
      ],
      body: {}
    )
    #expect(!testCase.id.isStable)
    let arguments = try #require(testCase.arguments)
    #expect(arguments.allSatisfy { !$0.id.isStable })
  }
}

// MARK: - Fixtures, helpers

private struct NonCodable {}

private struct IssueRecordingEncodable: Encodable {
  func encode(to encoder: any Encoder) throws {
    Issue.record("Unexpected attempt to encode an instance of \(Self.self)")
  }
}
