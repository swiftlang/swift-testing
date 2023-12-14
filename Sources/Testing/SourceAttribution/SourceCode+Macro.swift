//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension SourceCode {
  /// Create an instance of ``SourceCode`` representing a complete syntax node.
  ///
  /// - Parameters:
  ///   - syntaxNode: The complete syntax node (expression, declaration,
  ///     statement, etc.)
  ///
  /// - Returns: A new instance of ``SourceCode``.
  public static func __fromSyntaxNode(_ syntaxNode: String) -> Self {
    Self(kind: .syntaxNode(syntaxNode))
  }

  /// Create an instance of ``SourceCode`` representing a binary operation.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand operand.
  ///   - op: The operator.
  ///   - rhs: The right-hand operand.
  ///
  /// - Returns: A new instance of ``SourceCode``.
  public static func __fromBinaryOperation(_ lhs: String, _ op: String, _ rhs: String) -> Self {
    Self(kind: .binaryOperation(lhs: lhs, operator: op, rhs: rhs))
  }

  /// Create an instance of ``SourceCode`` representing a function call.
  ///
  /// - Parameters:
  ///   - value: The value on which the member function is being invoked, if
  ///     any.
  ///   - functionName: The name of the member function.
  ///   - argumentLabel: Optionally, the argument label.
  ///   - argumentValue: The value of the argument to the function.
  ///
  /// - Returns: A new instance of ``SourceCode``.
  public static func __functionCall(_ value: String?, _ functionName: String, _ arguments: (label: String?, value: String)...) -> Self {
    Self(kind: .functionCall(value: value, functionName: functionName, arguments: arguments))
  }

  /// Create an instance of ``SourceCode`` representing a property access.
  ///
  /// - Parameters:
  ///   - value: The value whose property was accessed.
  ///   - keyPath: The key path, relative to `value`, that was accessed, not
  ///     including a leading backslash or period.
  ///
  /// - Returns: A new instance of ``SourceCode``.
  public static func __fromPropertyAccess(_ value: String, _ keyPath: String) -> Self {
    Self(kind: .propertyAccess(value: value, keyPath: keyPath))
  }
}
