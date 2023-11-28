//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

public import SwiftSyntax
public import SwiftSyntaxMacros

/// The result of parsing the condition argument passed to `#expect()` or
/// `#require()`.
struct Condition {
  /// The name of the function to call in the macro expansion (e.g.
  /// `__check()`.)
  var expandedFunctionName: TokenSyntax

  /// The condition as one or more arguments to the evaluation function,
  /// suitable for passing as partial arguments to a call to `__check()`.
  var arguments: [Argument]

  /// The condition's source code as an expression that produces an instance of
  /// the testing library's `SourceCode` type.
  var sourceCode: ExprSyntax

  init(_ expandedFunctionName: String, arguments: [Argument], sourceCode: ExprSyntax) {
    self.expandedFunctionName = .identifier(expandedFunctionName)
    self.arguments = arguments
    self.sourceCode = sourceCode
  }

  /// Initialize an instance of this type representing a single expression (i.e.
  /// one that could not be broken down further.)
  ///
  /// - Parameters:
  ///   - expr: The expression.
  ///   - sourceCodeNode: The node from which to derive the `sourceCode`
  ///     property. If `nil`, `expr` is used.
  init(expression expr: some ExprSyntaxProtocol, sourceCodeNode: Syntax? = nil) {
    let sourceCodeNode: Syntax = sourceCodeNode ?? Syntax(expr)
    self.init(
      "__checkValue",
      arguments: [Argument(expression: expr)],
      sourceCode: createSourceCodeExpr(from: sourceCodeNode)
    )
  }
}

/// Emit a diagnostic if an expression resolves to a trivial boolean literal
/// (e.g. `#expect(true)`.)
///
/// - Parameters:
///   - expr: The condition expression to parse.
///   - macro: The macro expression being expanded.
///   - context: The macro context in which the expression is being parsed.
///
/// If `expr` is a trivial boolean expression, a diagnostic is emitted on the
/// assumption that this is not what the developer intended.
private func _diagnoseTrivialBooleanValue(from expr: ExprSyntax, for macro: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) {
  if let literal = expr.as(BooleanLiteralExprSyntax.self) {
    switch literal.literal.tokenKind {
    case .keyword(.true):
      context.diagnose(.condition(expr, isAlways: true, in: macro))
    case .keyword(.false):
      context.diagnose(.condition(expr, isAlways: false, in: macro))
    default:
      break
    }
  } else if let literal = _negatedExpression(expr, in: context)?.as(BooleanLiteralExprSyntax.self) {
    // This expression is of the form !true or !false.
    switch literal.literal.tokenKind {
    case .keyword(.true):
      context.diagnose(.condition(expr, isAlways: !true, in: macro))
    case .keyword(.false):
      context.diagnose(.condition(expr, isAlways: !false, in: macro))
    default:
      break
    }
  }
}

/// Extract the expression negated by another expression, assuming that the
/// input expression is the negation operator (`!`).
///
/// - Parameters:
///   - expr: The negation expression.
///
/// - Returns: The expression negated by `expr`, or `nil` if `expr` is not a
///   negation expression.
///
/// This function handles expressions such as `!foo` or `!(bar)`.
private func _negatedExpression(_ expr: ExprSyntax, in context: some MacroExpansionContext) -> ExprSyntax? {
  let expr = _removeParentheses(from: expr) ?? expr
  if let op = expr.as(PrefixOperatorExprSyntax.self),
     op.operator.tokenKind == .prefixOperator("!") {
    return _removeParentheses(from: op.expression) ?? op.expression
  }

  return nil
}

/// Remove the parentheses surrounding an expression, if present.
///
/// - Parameters:
///   - expr: The parenthesized expression.
///
/// - Returns: The expression parenthesized by `expr`, or `nil` if it wasn't
///   parenthesized.
///
/// This function handles expressions such as `(foo)` or `((foo, bar))`. It does
/// not remove interior parentheses (e.g. `(foo, (bar))`.)
private func _removeParentheses(from expr: ExprSyntax) -> ExprSyntax? {
  if let tuple = expr.as(TupleExprSyntax.self),
      tuple.elements.count == 1,
     let elementExpr = tuple.elements.first,
     elementExpr.label == nil {
    return _removeParentheses(from: elementExpr.expression) ?? elementExpr.expression
  }

  return nil
}

// MARK: -

/// Parse a condition argument from a binary operation expression.
///
/// - Parameters:
///   - expr: The expression to which `subexpressions` belong.
///   - lhs: The left-hand operand expression.
///   - op: The operator expression.
///   - rhs: The right-hand operand expression.
///   - macro: The macro expression being expanded.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: An instance of ``Condition`` describing `expr`.
///
/// This function currently only recognizes and converts simple binary operator
/// expressions. More complex expressions are treated as monolithic.
private func _parseCondition(from expr: ExprSyntax, leftOperand lhs: ExprSyntax, operator op: BinaryOperatorExprSyntax, rightOperand rhs: ExprSyntax, for macro: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) -> Condition {
  return Condition(
    "__checkBinaryOperation",
    arguments: [
      Argument(expression: lhs),
      Argument(expression: "{ $0 \(op.trimmed) $1() }"),
      Argument(expression: rhs)
    ],
    sourceCode: createSourceCodeExprForBinaryOperation(lhs, op, rhs)
  )
}

/// Parse a condition argument from an `is` expression.
///
/// - Parameters:
///   - expr: The `is` expression.
///   - macro: The macro expression being expanded.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: An instance of ``Condition`` describing `expr`.
private func _parseCondition(from expr: IsExprSyntax, for macro: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) -> Condition {
  let expression = expr.expression
  let type = expr.type

  return Condition(
    "__checkCast",
    arguments: [
      Argument(expression: expression),
      Argument(label: .identifier("is"), expression: "\(type.trimmed).self")
    ],
    sourceCode: createSourceCodeExprForBinaryOperation(expression, expr.isKeyword, type)
  )
}

/// Parse a condition argument from an `as?` expression.
///
/// - Parameters:
///   - expr: The `as?` expression.
///   - macro: The macro expression being expanded.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: An instance of ``Condition`` describing `expr`.
private func _parseCondition(from expr: AsExprSyntax, for macro: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) -> Condition {
  let expression = expr.expression
  let type = expr.type

  switch expr.questionOrExclamationMark?.tokenKind {
  case .postfixQuestionMark:
    return Condition(
      "__checkCast",
      arguments: [
        Argument(expression: expression),
        Argument(label: .identifier("as"), expression: "\(type.trimmed).self")
      ],
      sourceCode: createSourceCodeExprForBinaryOperation(expression, TokenSyntax.unknown("as?"), type)
    )

  case .exclamationMark where !type.isNamed("Bool", inModuleNamed: "Swift") && !type.isOptional:
    // Warn that as! will be evaluated before #expect() or #require(), which is
    // probably not what the developer intended. We suppress the warning for
    // casts to Bool and casts to optional types. Presumably such casts are not
    // being performed for their optional-unwrapping behavior, but because the
    // developer knows the type of the expression better than we do.
    context.diagnose(.asExclamationMarkIsEvaluatedEarly(expr, in: macro))

  default:
    // Only diagnose for `x as! T`. `x as T` is perfectly fine if it otherwise
    // compiles. For example, `#require(x as Int?)` should compile.
    //
    // If the token after "as" is something else entirely and got through the
    // type checker, just leave it alone as we don't recognize it.
    break
  }

  return Condition(expression: expr)
}

/// Parse a condition argument from a closure expression.
///
/// - Parameters:
///   - expr: The closure expression.
///   - macro: The macro expression being expanded.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: An instance of ``Condition`` describing `expr`.
private func _parseCondition(from expr: ClosureExprSyntax, for macro: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) -> Condition {
  if expr.signature == nil && expr.statements.count == 1, let item = expr.statements.first?.item {
    if case let .expr(bodyExpr) = item {
      return Condition(
        "__checkValue",
        arguments: [Argument(expression: expr)],
        sourceCode: _parseCondition(from: bodyExpr, for: macro, in: context).sourceCode
      )
    }

    // If a closure contains a single statement or declaration, we can't
    // meaningfully break it down as an expression, but we can still capture its
    // source representation.
    return Condition(expression: expr, sourceCodeNode: Syntax(item))
  }

  return Condition(expression: expr)
}

/// Parse a condition argument from a member function call.
///
/// - Parameters:
///   - expr: The function call expression.
///   - memberAccessExpr: The called expression of `expr`.
///   - macro: The macro expression being expanded.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: An instance of ``Condition`` describing `expr`.
private func _parseCondition(from expr: FunctionCallExprSyntax, for macro: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) -> Condition {
  // If the member function call involves the `try` or `await` keywords, assume
  // we cannot expand it. This check cannot handle expressions like
  // `try #expect(a.b(c))` where `b()` is throwing because the `try` keyword
  // is outside the macro expansion. SEE: rdar://109470248
  let containsTryOrAwait = expr.tokens(viewMode: .sourceAccurate).lazy
    .map(\.tokenKind)
    .contains { $0 == .keyword(.try) || $0 == .keyword(.await) }
  if containsTryOrAwait {
    return Condition(expression: expr)
  }

  // We do not support function calls with trailing closures because the
  // transform required to forward them requires more information than is
  // available solely from the syntax tree.
  if expr.trailingClosure != nil {
    return Condition(expression: expr)
  }

  // We also do not support expansion of closure invocations as they are
  // diagnostically uninteresting.
  if expr.calledExpression.is(ClosureExprSyntax.self) {
    return Condition(expression: expr)
  }

  let memberAccessExpr = expr.calledExpression.as(MemberAccessExprSyntax.self)
  let functionName = memberAccessExpr.map(\.declName.baseName).map(Syntax.init) ?? Syntax(expr.calledExpression)
  let argumentList = expr.arguments.map(Argument.init)

  let inOutArguments: [InOutExprSyntax] = argumentList.lazy
    .map(\.expression)
    .compactMap({ $0.as(InOutExprSyntax.self) })
  if inOutArguments.count > 1 {
    // There is more than one inout argument present. This requires that the
    // corresponding __check() function support variadic generics, but there is
    // a compiler bug preventing us from implementing variadic inout support.
    return Condition(expression: expr)
  } else if inOutArguments.count != 0 && inOutArguments.count != argumentList.count {
    // There is a mix of inout and normal arguments. That's not feasible for
    // us to support here, so back out.
    return Condition(expression: expr)
  }

  // Which __check() function are we calling?
  let expandedFunctionName = inOutArguments.isEmpty ? "__checkFunctionCall" : "__checkInoutFunctionCall"

  let indexedArguments = argumentList.lazy
    .enumerated()
    .map { index, argument in
      if argument.expression.is(InOutExprSyntax.self) {
        return Argument(label: argument.label, expression: "&$\(raw: index + 1)")
      }
      return Argument(label: argument.label, expression: "$\(raw: index + 1)")
    }
  let forwardedArguments = argumentList.lazy
    .map(\.expression)
    .map { Argument(expression: $0) }

  var conditionArguments = [Argument]()
  if let memberAccessExpr, let baseExpr = memberAccessExpr.base {
    conditionArguments.append(Argument(expression: "\(baseExpr.trimmed).self")) // BUG: rdar://113152370
    conditionArguments.append(
      Argument(
        label: "calling",
        expression: """
        {
          $0.\(functionName.trimmed)(\(LabeledExprListSyntax(indexedArguments)))
        }
        """
      )
    )
  } else {
    // Substitute an empty tuple for the self argument, and call the function
    // directly (without having to reorder the numbered closure arguments.) If
    // the function takes zero arguments, we'll also need to suppress $0 in the
    // closure body since it is unused.
    let parameterList = forwardedArguments.isEmpty ? "_ in" : ""
    conditionArguments.append(Argument(expression: "()"))
    conditionArguments.append(
      Argument(
        label: "calling",
        expression: """
        { \(raw: parameterList)
          \(functionName.trimmed)(\(LabeledExprListSyntax(indexedArguments)))
        }
        """
      )
    )
  }
  conditionArguments += forwardedArguments
  return Condition(
    expandedFunctionName,
    arguments: conditionArguments,
    sourceCode: createSourceCodeExprForFunctionCall(memberAccessExpr?.base, functionName, argumentList)
  )
}

/// Parse a condition argument from an arbitrary expression.
///
/// - Parameters:
///   - expr: The condition expression to parse.
///   - macro: The macro expression being expanded.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: An instance of ``Condition`` describing `expr`.
private func _parseCondition(from expr: ExprSyntax, for macro: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) -> Condition {
  if let infixOperator = expr.as(InfixOperatorExprSyntax.self),
     let op = infixOperator.operator.as(BinaryOperatorExprSyntax.self) {
    return _parseCondition(from: expr, leftOperand: infixOperator.leftOperand, operator: op, rightOperand: infixOperator.rightOperand, for: macro, in: context)
  }

  // Handle `is` and `as?` expressions.
  if let isExpr = expr.as(IsExprSyntax.self) {
    return _parseCondition(from: isExpr, for: macro, in: context)
  } else if let asExpr = expr.as(AsExprSyntax.self) {
    return _parseCondition(from: asExpr, for: macro, in: context)
  }

  // Handle closures with a single expression in them (e.g. { $0.foo() })
  if let closureExpr = expr.as(ClosureExprSyntax.self) {
    return _parseCondition(from: closureExpr, for: macro, in: context)
  }

  // Handle function calls.
  if let functionCallExpr = expr.as(FunctionCallExprSyntax.self) {
    return _parseCondition(from: functionCallExpr, for: macro, in: context)
  }

  // Parentheses are parsed as if they were tuples, so (true && false) appears
  // to the parser as a tuple containing one expression, `true && false`.
  if let expr = _removeParentheses(from: expr) {
    return _parseCondition(from: expr, for: macro, in: context)
  }

  return Condition(expression: expr)
}

// MARK: -

/// Parse a condition argument from an arbitrary expression.
///
/// - Parameters:
///   - expr: The condition expression to parse.
///   - macro: The macro expression being expanded.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: An instance of ``Condition`` describing `expr`.
func parseCondition(from expr: ExprSyntax, for macro: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) -> Condition {
  let result = _parseCondition(from: expr, for: macro, in: context)
  if result.arguments.count == 1, let onlyArgument = result.arguments.first {
    _diagnoseTrivialBooleanValue(from: onlyArgument.expression, for: macro, in: context)
  }
  return result
}
