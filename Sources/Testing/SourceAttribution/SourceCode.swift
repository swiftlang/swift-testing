//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing the source code of an expression.
///
/// Instances of this type may represent simple strings containing the source
/// code of an expression, or may represent more deeply structured data that
/// can still be represented as a string when needed.
public struct SourceCode: Sendable {
  /// An enumeration describing the various kinds of source code that can be
  /// captured.
  ///
  /// This type is not part of the public interface of the testing library.
  enum Kind: Sendable {
    /// The source code represents a single, complete syntax node.
    case syntaxNode(String)

    /// The source code represents a binary operation.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand operand.
    ///   - operator: The operator.
    ///   - rhs: The right-hand operand.
    case binaryOperation(lhs: String, `operator`: String, rhs: String)

    /// The source code represents a function call.
    ///
    /// - Parameters:
    ///   - value: The value on which the function was called, if any.
    ///   - functionName: The name of the function that was called.
    ///   - arguments: The arguments passed to the function.
    case functionCall(value: String?, functionName: String, arguments: [(label: String?, value: String)])
  }

  /// The kind of syntax node represented by this instance.
  ///
  /// This property is not part of the public interface of the testing library.
  /// Use `String(describing:)` to access the source code represented by an
  /// instance of this type.
  var kind: Kind

  /// Assuming this instance represents a binary operator expression, expand its
  /// string representation to include the actual runtime values of its left-
  /// and right-hand operands. The `rhs` parameter is optional and may be `nil`
  /// if it was not evaluated at runtime, which may occur due to operator short-
  /// circuiting.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand operand to the expression.
  ///   - additionalValues: The right-hand operand to the expression, arguments
  ///     to the function call, etc.
  ///
  /// - Returns: A string containing this instance's components along with
  ///   descriptions of the operands `lhs` and `rhs` inserted next to their
  ///   corresponding source code representations. If this instance does not
  ///   appear to represent a binary operator expression, the description of
  ///   this instance is returned.
  func expandWithOperands<each T>(_ lhs: some Any, _ additionalValues: repeat (each T)?) -> String {
    func sourceCodeAndValue(_ sourceCode: String, _ value: Any?, includeParenthesesIfNeeded: Bool = true) -> String {
      guard let value else {
        return "<not evaluated>"
      }

      let valueDescription = String(describingForTest: value)

      if valueDescription == "(Function)" {
        // Hack: don't print string representations of function calls.
        return sourceCode
      } else if valueDescription == sourceCode {
        return sourceCode
      } else if includeParenthesesIfNeeded {
        return "(\(sourceCode) → \(valueDescription))"
      } else {
        return "\(sourceCode) → \(valueDescription)"
      }
    }

    // Convert the variadic generic argument list to an array.
    var additionalValuesArray = [Any?]()
    repeat additionalValuesArray.append(each additionalValues)

    switch kind {
    case let .syntaxNode(syntaxNode):
      return syntaxNode
    case let .binaryOperation(lhsExpr, op, rhsExpr):
      let rhs = additionalValuesArray.first
      return "\(sourceCodeAndValue(lhsExpr, lhs)) \(op) \(sourceCodeAndValue(rhsExpr, rhs ?? nil))"
    case let .functionCall(value, functionName, arguments):
      let includeParentheses = arguments.count > 1
      let argumentList = zip(arguments, additionalValuesArray).lazy
        .map { argument, value in
          if let argumentLabel = argument.label {
            return "\(argumentLabel): \(sourceCodeAndValue(argument.value, value, includeParenthesesIfNeeded: includeParentheses))"
          }
          return sourceCodeAndValue(argument.value, value, includeParenthesesIfNeeded: includeParentheses)
        }.joined(separator: ", ")
      if let value {
        return "\(sourceCodeAndValue(value, lhs)).\(functionName)(\(argumentList))"
      }
      return "\(functionName)(\(argumentList))"
    }
  }
}

// MARK: - CustomStringConvertible, CustomDebugStringConvertible

extension SourceCode: CustomStringConvertible, CustomDebugStringConvertible {
  /// Initialize an instance of this type containing the specified source code.
  ///
  /// - Parameters:
  ///   - stringValue: The source code of the expression being described.
  ///
  /// To get the string value of an instance of ``SourceCode``, pass it to
  /// `String(describing:)`.
  ///
  /// This initializer does not attempt to parse `stringValue`.
  public init(_ stringValue: String) {
    self.init(kind: .syntaxNode(stringValue))
  }

  public var description: String {
    switch kind {
    case let .syntaxNode(syntaxNode):
      return syntaxNode
    case let .binaryOperation(lhs, op, rhs):
      return "\(lhs) \(op) \(rhs)"
    case let .functionCall(value, functionName, arguments):
      let argumentList = arguments.lazy
        .map { argument in
          if let argumentLabel = argument.label {
            return "\(argumentLabel): \(argument.value)"
          }
          return argument.value
        }.joined(separator: ", ")
      if let value {
        return "\(value).\(functionName)(\(argumentList))"
      }
      return "\(functionName)(\(argumentList))"
    }
  }

  public var debugDescription: String {
    return String(describing: kind)
  }
}

// MARK: - Codable

extension SourceCode: Codable {}

extension SourceCode.Kind: Codable {
  enum CodingKeys: CodingKey {
    case syntaxNode
    case binaryOperation
    case functionCall

    enum SyntaxNodeKeys: CodingKey {
      case text
    }

    enum BinaryOperationKeys: CodingKey {
      case lhs
      case `operator`
      case rhs
    }

    enum FunctionCallKeys: CodingKey {
      case value
      case functionName
      case arguments

      enum ArgumentKeys: CodingKey {
        case label
        case value
      }
    }
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let syntaxNodeContainer = try? container.nestedContainer(keyedBy: CodingKeys.SyntaxNodeKeys.self,
                                                                forKey: .syntaxNode) {
      self = .syntaxNode(try syntaxNodeContainer.decode(String.self,
                                                        forKey: .text))
    } else if let binaryOperationContainer = try? container.nestedContainer(keyedBy: CodingKeys.BinaryOperationKeys.self,
                                                                            forKey: .binaryOperation) {
      self = .binaryOperation(lhs: try binaryOperationContainer.decode(String.self,
                                                                       forKey: .lhs),
                              operator: try binaryOperationContainer.decode(String.self,
                                                                            forKey: .operator),
                              rhs: try binaryOperationContainer.decode(String.self,
                                                                       forKey: .rhs))
    } else if let functionCallContainer = try? container.nestedContainer(keyedBy: CodingKeys.FunctionCallKeys.self,
                                                                         forKey: .functionCall) {
      self = .functionCall(value: try functionCallContainer.decodeIfPresent(String.self,
                                                                            forKey: .value),
                           functionName: try functionCallContainer.decode(String.self,
                                                                          forKey: .functionName),
                           arguments: try {
        var argumentsContainer = try functionCallContainer.nestedUnkeyedContainer(forKey: .arguments)

        var arguments = [(label: String?, value: String)]()
        while !argumentsContainer.isAtEnd {
          let argumentContainer = try argumentsContainer.nestedContainer(keyedBy: CodingKeys.FunctionCallKeys.ArgumentKeys.self)
          let label = try argumentContainer.decodeIfPresent(String.self, forKey: .label)
          let value = try argumentContainer.decode(String.self, forKey: .value)
          arguments.append((label: label, value: value))
        }
        return arguments
      }())
    } else {
      throw DecodingError.valueNotFound(
        Self.self,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Value found did not match any of the existing cases for SourceCode.Kind."
        )
      )
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .syntaxNode(text):
      var syntaxNodeContainer = container.nestedContainer(keyedBy: CodingKeys.SyntaxNodeKeys.self,
                                                          forKey: .syntaxNode)
      try syntaxNodeContainer.encode(text, forKey: .text)
    case let .binaryOperation(lhs: lhs, operator: `operator`, rhs: rhs):
      var binaryOperationContainer = container.nestedContainer(keyedBy: CodingKeys.BinaryOperationKeys.self,
                                                               forKey: .binaryOperation)
      try binaryOperationContainer.encode(lhs, forKey: .lhs)
      try binaryOperationContainer.encode(`operator`, forKey: .operator)
      try binaryOperationContainer.encode(rhs, forKey: .rhs)
    case let .functionCall(value: value,
                           functionName: functionName,
                           arguments: arguments):
      var functionCallContainer = container.nestedContainer(keyedBy: CodingKeys.FunctionCallKeys.self,
                                                            forKey: .functionCall)
      try functionCallContainer.encodeIfPresent(value, forKey: .value)
      try functionCallContainer.encode(functionName, forKey: .functionName)

      var argumentsContainer = functionCallContainer.nestedUnkeyedContainer(forKey: .arguments)
      for argument in arguments {
        var argumentContainer = argumentsContainer.nestedContainer(keyedBy: CodingKeys.FunctionCallKeys.ArgumentKeys.self)
        try argumentContainer.encode(argument.label, forKey: .label)
        try argumentContainer.encode(argument.value, forKey: .value)
      }
    }
  }
}
