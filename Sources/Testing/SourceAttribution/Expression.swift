//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing a Swift expression captured at compile-time from source
/// code.
///
/// Instances of this type are generally opaque to callers. They can be
/// converted to strings representing their source code (captured at compile
/// time) using `String.init(describing:)`.
///
/// If parsing is needed, use the swift-syntax package to convert an instance of
/// this type to an instance of `ExprSyntax` using a Swift expression such as:
///
/// ```swift
/// let swiftSyntaxExpr: ExprSyntax = "\(testExpr)"
/// ```
public struct Expression: Sendable {
  /// An enumeration describing the various kinds of expression that can be
  /// captured.
  ///
  /// This type is not part of the public interface of the testing library.
  enum Kind: Sendable {
    /// The expression represents a single, complete syntax node.
    ///
    /// - Parameters:
    ///   - sourceCode: The source code of the represented expression.
    case generic(_ sourceCode: String)

    /// The expression represents a binary operation.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand operand.
    ///   - operator: The operator.
    ///   - rhs: The right-hand operand.
    indirect case binaryOperation(lhs: Expression, `operator`: String, rhs: Expression)

    /// A type representing an argument to a function call, used by the
    /// ``Expression/Kind/functionCall`` case.
    ///
    /// This type is not part of the public interface of the testing library.
    struct FunctionCallArgument: Sendable {
      /// The label, if present, of the argument.
      var label: String?

      /// The value, as an expression, of the argument.
      var value: Expression
    }

    /// The expression represents a function call.
    ///
    /// - Parameters:
    ///   - value: The value on which the function was called, if any.
    ///   - functionName: The name of the function that was called.
    ///   - arguments: The arguments passed to the function.
    indirect case functionCall(value: Expression?, functionName: String, arguments: [FunctionCallArgument])

    /// The expression represets a property access.
    ///
    /// - Parameters:
    ///   - value: The value whose property was accessed.
    ///   - keyPath: The key path, relative to `value`, that was accessed, not
    ///     including a leading backslash or period.
    indirect case propertyAccess(value: Expression, keyPath: Expression)
  }

  /// The kind of syntax node represented by this instance.
  ///
  /// This property is not part of the public interface of the testing library.
  /// Use `String(describing:)` to access the source code represented by an
  /// instance of this type.
  var kind: Kind

  /// The source code of the original captured expression.
  @_spi(ExperimentalSourceCodeCapturing)
  public var sourceCode: String {
    switch kind {
    case let .generic(sourceCode):
      return sourceCode
    case let .binaryOperation(lhs, op, rhs):
      return "\(lhs) \(op) \(rhs)"
    case let .functionCall(value, functionName, arguments):
      let argumentList = arguments.lazy
        .map { argument in
          if let argumentLabel = argument.label {
            return "\(argumentLabel): \(argument.value.sourceCode)"
          }
          return argument.value.sourceCode
        }.joined(separator: ", ")
      if let value {
        return "\(value.sourceCode).\(functionName)(\(argumentList))"
      }
      return "\(functionName)(\(argumentList))"
    case let .propertyAccess(value, keyPath):
      return "\(value.sourceCode).\(keyPath.sourceCode)"
    }
  }

  /// A description, captured using ``String/init(describingForTest:)``, of
  /// the runtime value of this subexpression.
  ///
  /// If the runtime value of this subexpression has not been evaluated, the
  /// value of this property is `nil`.
  @_spi(ExperimentalSourceCodeCapturing)
  public var runtimeValueDescription: String?

  /// The fully-qualified name of the type of this subexpression's runtime
  /// value.
  ///
  /// If the runtime value of this subexpression has not been evaluated, the
  /// value of this property is `nil`.
  @_spi(ExperimentalSourceCodeCapturing)
  public var fullyQualifiedTypeNameOfRuntimeValue: String?

  /// Copy this instance and capture the runtime values corresponding to its
  /// subexpressions.
  ///
  /// - Parameters:
  ///   - firstValue: The first captured runtime value.
  ///   - additionalValues: Any additional captured runtime values after the
  ///     first.
  ///
  /// - Returns: A copy of `self` with information about the specified runtime
  ///   values captured for future use.
  func capturingRuntimeValues<each T>(_ firstValue: (some Any)?, _ additionalValues: repeat (each T)?) -> Self {
    var result = self

    // Convert the variadic generic argument list to an array.
    var additionalValuesArray = [Any?]()
    repeat additionalValuesArray.append(each additionalValues)

    switch kind {
    case .generic:
      if let firstValue {
        result.runtimeValueDescription = String(describingForTest: firstValue)
        result.fullyQualifiedTypeNameOfRuntimeValue = _typeName(type(of: firstValue as Any), qualified: true)
      } else {
        result.runtimeValueDescription = nil
        result.fullyQualifiedTypeNameOfRuntimeValue = nil
      }
    case let .binaryOperation(lhsExpr, op, rhsExpr):
      result.kind = .binaryOperation(
        lhs: lhsExpr.capturingRuntimeValues(firstValue),
        operator: op,
        rhs: rhsExpr.capturingRuntimeValues(additionalValuesArray.first ?? nil)
      )
    case let .functionCall(value, functionName, arguments):
      result.kind = .functionCall(
        value: value?.capturingRuntimeValues(firstValue),
        functionName: functionName,
        arguments: zip(arguments, additionalValuesArray).map { argument, value in
          .init(label: argument.label, value: argument.value.capturingRuntimeValues(value))
        }
      )
    case let .propertyAccess(value, keyPath):
      result.kind = .propertyAccess(
        value: value.capturingRuntimeValues(firstValue),
        keyPath: keyPath.capturingRuntimeValues(additionalValuesArray.first ?? nil)
      )
    }

    return result
  }

  /// Get an expanded description of this instance that contains the source
  /// code and runtime value (or values) it represents.
  ///
  /// - Parameters:
  ///   - includingParenthesesIfNeeded: Whether or not to enclose the
  ///     resulting string in parentheses (as needed depending on what
  ///     information this instance contains.)
  ///
  /// - Returns: A string describing this instance.
  func expandedDescription(includingParenthesesIfNeeded: Bool = true) -> String {
    switch kind {
    case let .generic(sourceCode):
      let runtimeValueDescription = runtimeValueDescription ?? "<not evaluated>"
      return if runtimeValueDescription == "(Function)" {
        // Hack: don't print string representations of function calls.
        sourceCode
      } else if runtimeValueDescription == sourceCode {
        sourceCode
      } else if includingParenthesesIfNeeded {
        "(\(sourceCode) → \(runtimeValueDescription))"
      } else {
        "\(sourceCode) → \(runtimeValueDescription)"
      }
    case let .binaryOperation(lhsExpr, op, rhsExpr):
      return "\(lhsExpr.expandedDescription()) \(op) \(rhsExpr.expandedDescription())"
    case let .functionCall(value, functionName, arguments):
      let includeParentheses = arguments.count > 1
      let argumentList = arguments.lazy
        .map { argument in
          (argument.label, argument.value.expandedDescription(includingParenthesesIfNeeded: includeParentheses))
        }.map { label, value in
          if let label {
            return "\(label): \(value)"
          }
          return value
        }.joined(separator: ", ")
      if let value {
        return "\(value.expandedDescription()).\(functionName)(\(argumentList))"
      }
      return "\(functionName)(\(argumentList))"
    case let .propertyAccess(value, keyPath):
      return "\(value.expandedDescription()).\(keyPath.expandedDescription(includingParenthesesIfNeeded: false))"
    }
  }

  /// The set of parsed and captured subexpressions contained in this instance.
  @_spi(ExperimentalSourceCodeCapturing)
  public var subexpressions: [Expression] {
    switch kind {
    case .generic:
      []
    case let .binaryOperation(lhs, _, rhs):
      [lhs, rhs]
    case let .functionCall(value, _, arguments):
      if let value {
        CollectionOfOne(value) + arguments.lazy.map(\.value)
      } else {
        arguments.lazy.map(\.value)
      }
    case let .propertyAccess(value: value, keyPath: keyPath):
      [value, keyPath]
    }
  }
}

extension Expression: Codable {}
extension Expression.Kind: Codable {}
extension Expression.Kind.FunctionCallArgument: Codable {}

extension Expression: CustomStringConvertible, CustomDebugStringConvertible {
  /// Initialize an instance of this type containing the specified source code.
  ///
  /// - Parameters:
  ///   - sourceCode: The source code of the expression being described.
  ///
  /// To get the string value of an instance of ``Expression``, pass it to
  /// `String.init(describing:)`.
  ///
  /// This initializer does not attempt to parse `sourceCode`.
  public init(_ sourceCode: String) {
    self.init(kind: .generic(sourceCode))
  }

  public var description: String {
    sourceCode
  }

  public var debugDescription: String {
    String(reflecting: kind)
  }
}
