//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension ABIv0 {
  /// A type implementing the JSON encoding of ``Expectation`` for the ABI entry
  /// point and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  ///
  /// - Warning: Expectations are not yet part of the JSON schema.
  struct EncodedExpectation: Sendable {
    /// The expression evaluated by this expectation.
    ///
    /// - Warning: Expressions are not yet part of the JSON schema.
    var _expression: EncodedExpression

    init(encoding expectation: borrowing Expectation, in eventContext: borrowing Event.Context) {
      _expression = EncodedExpression(encoding: expectation.evaluatedExpression, in: eventContext)
    }
  }
}

// MARK: - Codable

extension ABIv0.EncodedExpectation: Codable {}
