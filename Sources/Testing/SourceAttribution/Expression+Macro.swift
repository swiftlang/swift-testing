//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Expression {
  /// Create an instance of ``Expression`` representing a complete syntax node.
  ///
  /// - Parameters:
  ///   - syntaxNode: The complete syntax node (expression, declaration,
  ///     statement, etc.)
  ///
  /// - Returns: A new instance of ``Expression``.
  ///
  /// - Warning: This function is used to implement the `@Test`, `@Suite`,
  ///   `#expect()` and `#require()` macros. Do not call it directly.
  public static func __fromSyntaxNode(_ syntaxNode: String) -> Self {
    Self(kind: .generic(syntaxNode))
  }

  /// Create an instance of ``Expression`` representing a string literal.
  ///
  /// - Parameters:
  ///   - sourceCode: The source code representation of the string literal,
  ///     including leading and trailing punctuation.
  ///   - stringValue: The actual string value of the string literal
  ///
  /// - Returns: A new instance of ``Expression``.
  ///
  /// - Warning: This function is used to implement the `@Test`, `@Suite`,
  ///   `#expect()` and `#require()` macros. Do not call it directly.
  public static func __fromStringLiteral(_ sourceCode: String, _ stringValue: String) -> Self {
    Self(kind: .stringLiteral(sourceCode: sourceCode, stringValue: stringValue))
  }

  /// Create an instance of ``Expression`` representing a binary operation.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand operand.
  ///   - op: The operator.
  ///   - rhs: The right-hand operand.
  ///
  /// - Returns: A new instance of ``Expression``.
  ///
  /// - Warning: This function is used to implement the `@Test`, `@Suite`,
  ///   `#expect()` and `#require()` macros. Do not call it directly.
  public static func __fromBinaryOperation(_ lhs: Expression, _ op: String, _ rhs: Expression) -> Self {
    return Self(kind: .binaryOperation(lhs: lhs, operator: op, rhs: rhs))
  }

  /// Create an instance of ``Expression`` representing a function call.
  ///
  /// - Parameters:
  ///   - value: The value on which the member function is being invoked, if
  ///     any.
  ///   - functionName: The name of the member function.
  ///   - argumentLabel: Optionally, the argument label.
  ///   - argumentValue: The value of the argument to the function.
  ///
  /// - Returns: A new instance of ``Expression``.
  ///
  /// - Warning: This function is used to implement the `@Test`, `@Suite`,
  ///   `#expect()` and `#require()` macros. Do not call it directly.
  public static func __fromFunctionCall(_ value: Expression?, _ functionName: String, _ arguments: (label: String?, value: Expression)...) -> Self {
    let arguments = arguments.map(Expression.Kind.FunctionCallArgument.init)
    return Self(kind: .functionCall(value: value, functionName: functionName, arguments: arguments))
  }

  /// Create an instance of ``Expression`` representing a property access.
  ///
  /// - Parameters:
  ///   - value: The value whose property was accessed.
  ///   - keyPath: The key path, relative to `value`, that was accessed, not
  ///     including a leading backslash or period.
  ///
  /// - Returns: A new instance of ``Expression``.
  ///
  /// - Warning: This function is used to implement the `@Test`, `@Suite`,
  ///   `#expect()` and `#require()` macros. Do not call it directly.
  public static func __fromPropertyAccess(_ value: Expression, _ keyPath: Expression) -> Self {
    return Self(kind: .propertyAccess(value: value, keyPath: keyPath))
  }

  /// Create an instance of ``Expression`` representing a negated expression
  /// using the `!` operator..
  ///
  /// - Parameters:
  ///   - expression: The expression that was negated.
  ///   - isParenthetical: Whether or not `expression` was enclosed in
  ///     parentheses (and the `!` operator was outside it.) This argument
  ///     affects how this expression is represented as a string.
  ///
  /// - Returns: A new instance of ``Expression``.
  ///
  /// - Warning: This function is used to implement the `@Test`, `@Suite`,
  ///   `#expect()` and `#require()` macros. Do not call it directly.
  public static func __fromNegation(_ expression: Expression, _ isParenthetical: Bool) -> Self {
    return Self(kind: .negation(expression, isParenthetical: isParenthetical))
  }
}
