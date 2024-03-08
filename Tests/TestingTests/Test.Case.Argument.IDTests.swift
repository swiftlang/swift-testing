//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ExperimentalTestRunning) @_spi(ForToolsIntegrationOnly) @_spi(ExperimentalEventHandling) import Testing
#if canImport(Foundation)
import Foundation
#endif

@Suite("Test.Case.Argument.ID Tests")
struct Test_Case_Argument_IDTests {
  @Test("One Codable parameter")
  func oneCodableParameter() async throws {
    let test = Test(
      arguments: [123],
      parameters: [Test.Parameter(index: 0, firstName: "value", type: Int.self)]
    ) { _ in }
    let testCases = try #require(test.testCases)
    let testCase = try #require(testCases.first { _ in true })
    #expect(testCase.arguments.count == 1)
    let argument = try #require(testCase.arguments.first)
    let argumentID = try #require(argument.id)
    #expect(String(bytes: argumentID.bytes, encoding: .utf8) == "123")
  }

  @Test("One CustomTestArgumentEncodable parameter")
  func oneCustomParameter() async throws {
    let test = Test(
      arguments: [MyCustomTestArgument(x: 123, y: "abc")],
      parameters: [Test.Parameter(index: 0, firstName: "value", type: MyCustomTestArgument.self)]
    ) { _ in }
    let testCases = try #require(test.testCases)
    let testCase = try #require(testCases.first { _ in true })
    #expect(testCase.arguments.count == 1)
    let argument = try #require(testCase.arguments.first)
    let argumentID = try #require(argument.id)
#if canImport(Foundation)
    let decodedArgument = try JSONDecoder().decode(MyCustomTestArgument.self, from: Data(argumentID.bytes))
    #expect(decodedArgument == MyCustomTestArgument(x: 123, y: "abc"))
#endif
  }

  @Test("One Identifiable parameter")
  func oneIdentifiableParameter() async throws {
    let test = Test(
      arguments: [MyIdentifiableArgument(id: "abc")],
      parameters: [Test.Parameter(index: 0, firstName: "value", type: MyIdentifiableArgument.self)]
    ) { _ in }
    let testCases = try #require(test.testCases)
    let testCase = try #require(testCases.first { _ in true })
    #expect(testCase.arguments.count == 1)
    let argument = try #require(testCase.arguments.first)
    let argumentID = try #require(argument.id)
    #expect(String(bytes: argumentID.bytes, encoding: .utf8) == #""abc""#)
  }

  @Test("One RawRepresentable parameter")
  func oneRawRepresentableParameter() async throws {
    let test = Test(
      arguments: [MyRawRepresentableArgument(rawValue: "abc")],
      parameters: [Test.Parameter(index: 0, firstName: "value", type: MyRawRepresentableArgument.self)]
    ) { _ in }
    let testCases = try #require(test.testCases)
    let testCase = try #require(testCases.first { _ in true })
    #expect(testCase.arguments.count == 1)
    let argument = try #require(testCase.arguments.first)
    let argumentID = try #require(argument.id)
    #expect(String(bytes: argumentID.bytes, encoding: .utf8) == #""abc""#)
  }
}

// MARK: - Fixture parameter types

private struct MyCustomTestArgument: CustomTestArgumentEncodable, Equatable {
  var x: Int
  var y: String

  private enum CodingKeys: CodingKey {
    case x, y
  }

  func encodeTestArgument(to encoder: some Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(x, forKey: .x)
    try container.encode(y, forKey: .y)
  }
}

extension MyCustomTestArgument: Decodable {}

@available(*, unavailable, message: "Intentionally not Encodable")
extension MyCustomTestArgument: Encodable {}

private struct MyIdentifiableArgument: Identifiable {
  var id: String
}

private struct MyRawRepresentableArgument: RawRepresentable {
  var rawValue: String
}
