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
  @_spi(Experimental)
  public struct EncodedExpression<V>: Sendable where V: ABI.Version {
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
  }
}

// MARK: - Codable

extension ABI.EncodedExpression: Codable {}

// MARK: - Conversion to/from library types

extension ABI.EncodedExpression {
  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - expression: The expression to initialize this instance from.
  public init(encoding expression: borrowing Expression) {
    sourceCode = expression.sourceCode
    runtimeValue = expression.runtimeValue.map(String.init(describingForTest:))
    runtimeTypeName = expression.runtimeValue.map(\.typeInfo.fullyQualifiedName)
    let subexpressions = expression.subexpressions
    if !subexpressions.isEmpty {
      children = subexpressions.map(Self.init(encoding:))
    }
  }
}

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension Expression {
  /// Initialize an instance of this type from the given value.
  ///
  /// - Parameters:
  ///   - expression: The encoded expression to initialize this instance from.
  public init?<V>(decoding expression: ABI.EncodedExpression<V>) {
    self.init(expression.sourceCode)
    if let runtimeValue = expression.runtimeValue,
       let runtimeTypeName = expression.runtimeTypeName {
      self.runtimeValue =  __Expression.Value(
        description: runtimeValue,
        typeInfo: TypeInfo(fullyQualifiedName: runtimeTypeName, mangledName: nil)
      )
    }
    if let children = expression.children {
      self.subexpressions = children.compactMap(__Expression.init(decoding:))
    }
  }
}
