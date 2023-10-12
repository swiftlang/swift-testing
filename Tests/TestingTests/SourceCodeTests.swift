//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable
@_spi(ExperimentalEventHandling)
@_spi(ExperimentalTestRunning)
import Testing
import Foundation

@Suite("SourceCode Tests")
struct SourceCodeTests {
  struct SourceCodeKindTests {
    @Test("Codable",
          arguments: [
            SourceCode.Kind.syntaxNode("Node"),
            SourceCode.Kind.binaryOperation(
              lhs: "lhs",
              operator: "operator",
              rhs: "rhs"
            ),
            SourceCode.Kind.functionCall(
              value: "value",
              functionName: "functionName",
              arguments: [
                (label: "argumentLabel1", value: "argumentValue1"),
                (label: "argumentLabel2", value: "argumentValue2")
              ]
            )
          ]
    )
    func codable(input: SourceCode.Kind) async throws {
      let encodedInput = try JSONEncoder().encode(input)
      let decodedInput = try JSONDecoder().decode(SourceCode.Kind.self,
                                                  from: encodedInput)

      switch (input, decodedInput) {
      case let (.syntaxNode(inputNode), .syntaxNode(decodedNode)):
        #expect(inputNode == decodedNode)
      case let (.binaryOperation(inputLhs, inputOperator, inputRhs),
                .binaryOperation(decodedInputLhs, decodedInputOperator, decodedInputRhs)):
        #expect(inputLhs == decodedInputLhs)
        #expect(inputOperator == decodedInputOperator)
        #expect(inputRhs == decodedInputRhs)
      case let (.functionCall(inputValue, inputFunctionName, inputArguments),
                .functionCall(decodedInputValue, decodedInputFunctionName, decodedInputArguments)):
        #expect(inputValue == decodedInputValue)
        #expect(inputFunctionName == decodedInputFunctionName)

        #expect(inputArguments.count == decodedInputArguments.count)
        for (inputArgument, decodedInputArgument) in zip(inputArguments, decodedInputArguments) {
          #expect(inputArgument.label == decodedInputArgument.label)
          #expect(inputArgument.value == decodedInputArgument.value)
        }
      default:
        Issue.record("Input (\(input)) is not the same case as the decoded input (\(decodedInput)).")
      }
    }
  }
}
