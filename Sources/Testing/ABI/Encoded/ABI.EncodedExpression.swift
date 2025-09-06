//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension ABI {
  /// A type implementing the JSON encoding of ``Expression`` for the ABI entry
  /// point and event stream output.
  ///
  /// This type is not part of the public interface of the testing library. It
  /// assists in converting values to JSON; clients that consume this JSON are
  /// expected to write their own decoders.
  ///
  /// - Warning: Expressions are not yet part of the JSON schema.
  struct EncodedExpression<V>: Sendable where V: ABI.Version {
    /// The source code of the original captured expression.
    var sourceCode: String

    /// A string representation of the runtime value of this expression.
    ///
    /// If the runtime value of this expression has not been evaluated, the
    /// value of this property is `nil`.
    var runtimeValue: String?

    /// The fully-qualified name of the type of value represented by
    /// `runtimeValue`, or `nil` if that value has not been captured.
    var runtimeTypeName: String?

    /// Any child expressions within this expression.
    var children: [EncodedExpression]?

    init(encoding expression: borrowing __Expression, in eventContext: borrowing Event.Context) {
      sourceCode = expression.sourceCode
      runtimeValue = expression.runtimeValue.map(String.init(describingForTest:))
      runtimeTypeName = expression.runtimeValue.map(\.typeInfo.fullyQualifiedName)
      if !expression.subexpressions.isEmpty {
        children = expression.subexpressions.map { [eventContext = copy eventContext] subexpression in
          Self(encoding: subexpression, in: eventContext)
        }
      }
    }
  }
}

// MARK: - Codable

extension ABI.EncodedExpression: Codable {}
