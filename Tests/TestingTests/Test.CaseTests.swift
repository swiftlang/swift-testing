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

#if canImport(Foundation)
private import Foundation
#endif

@Suite("Test.Case Tests")
struct Test_CaseTests {
  @Test func nonParameterized() throws {
    let testCase = Test.Case(body: {})
    #expect(testCase.id.argumentIDs == nil)
    #expect(testCase.id.discriminator == nil)
  }

  @Test func singleStableArgument() throws {
    let testCase = Test.Case(
      values: [1],
      parameters: [Test.Parameter(index: 0, firstName: "x", type: Int.self)],
      body: {}
    )
    #expect(testCase.id.isStable)
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
  }

  @Suite("Test.Case.ID Tests")
  struct IDTests {
#if canImport(Foundation)
    @Test func legacyDecoding_stable() throws {
      let encodedData = Data("""
        {"argumentIDs": [
          {"bytes": [1]}
        ]}
        """.utf8)
      let testCaseID = try JSON.decode(Test.Case.ID.self, from: encodedData)
      #expect(testCaseID.isStable)

      let argumentIDs = try #require(testCaseID.argumentIDs)
      #expect(argumentIDs.count == 1)
    }

    @Test func legacyDecoding_nonStable() throws {
      let encodedData = Data("{}".utf8)
      let testCaseID = try JSON.decode(Test.Case.ID.self, from: encodedData)
      #expect(!testCaseID.isStable)

      let argumentIDs = try #require(testCaseID.argumentIDs)
      #expect(argumentIDs.count == 1)
    }

    @Test func legacyDecoding_nonParameterized() throws {
      let encodedData = Data(#"{"argumentIDs": []}"#.utf8)
      let testCaseID = try JSON.decode(Test.Case.ID.self, from: encodedData)
      #expect(testCaseID.isStable)
      #expect(testCaseID.argumentIDs == nil)
      #expect(testCaseID.discriminator == nil)
    }

    @Test func newDecoding_nonParameterized() throws {
      let encodedData = Data(#"{"isStable": true}"#.utf8)
      let testCaseID = try JSON.decode(Test.Case.ID.self, from: encodedData)
      #expect(testCaseID.isStable)
      #expect(testCaseID.argumentIDs == nil)
      #expect(testCaseID.discriminator == nil)
    }

    @Test func newDecoding_parameterizedStable() throws {
      let encodedData = Data("""
        {
          "isStable": true,
          "argumentIDs": [
            {"bytes": [1]}
          ],
          "discriminator": 0
        }
        """.utf8)
      let testCaseID = try JSON.decode(Test.Case.ID.self, from: encodedData)
      #expect(testCaseID.isStable)
      #expect(testCaseID.argumentIDs?.count == 1)
      #expect(testCaseID.discriminator == 0)
    }
#endif
  }
}

// MARK: - Fixtures, helpers

private struct NonCodable {}

private struct IssueRecordingEncodable: Encodable {
  func encode(to encoder: any Encoder) throws {
    Issue.record("Unexpected attempt to encode an instance of \(Self.self)")
  }
}
