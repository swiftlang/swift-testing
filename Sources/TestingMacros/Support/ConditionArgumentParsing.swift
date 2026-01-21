//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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
  } else if let literal = _negatedExpression(expr)?.as(BooleanLiteralExprSyntax.self) {
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
private func _negatedExpression(_ expr: ExprSyntax) -> ExprSyntax? {
  let expr = removeParentheses(from: expr) ?? expr
  if let op = expr.as(PrefixOperatorExprSyntax.self),
     op.operator.tokenKind == .prefixOperator("!") {
    if let negatedExpr = removeParentheses(from: op.expression) {
      return negatedExpr
    } else {
      return op.expression
    }
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
func removeParentheses(from expr: ExprSyntax) -> ExprSyntax? {
  if let tuple = expr.as(TupleExprSyntax.self),
     tuple.elements.count == 1,
     let elementExpr = tuple.elements.first,
     elementExpr.label == nil {
    return removeParentheses(from: elementExpr.expression) ?? elementExpr.expression
  }

  return nil
}

// MARK: - Inserting expression context callouts

/// The maximum value of `_rewriteDepth` allowed by `_rewrite()` before it will
/// start bailing early.
private let _maximumRewriteDepth = {
  Int.max // disable rewrite-limiting (need to evaluate possible heuristics)
}()

/// A type that inserts calls to an `__ExpectationContext` instance into an
/// expression's syntax tree.
private final class _ContextInserter<C, M>: SyntaxRewriter where C: MacroExpansionContext, M: FreestandingMacroExpansionSyntax {
  /// The macro context in which the expression is being parsed.
  var context: C

  /// The macro expression.
  var macro: M

  /// The node to treat as the root node when expanding expressions.
  var effectiveRootNode: Syntax

  /// The name of the instance of `__ExpectationContext` to call.
  var expectationContextNameExpr: DeclReferenceExprSyntax

  /// A list of any syntax nodes that have been rewritten.
  ///
  /// The nodes in this array are the _original_ nodes, not the rewritten nodes.
  var rewrittenNodes = Set<Syntax>()

  /// Any postflight code the caller should insert into the closure containing
  /// the rewritten syntax tree.
  var teardownItems = [CodeBlockItemSyntax]()

  /// Whether or not the entire operation was cancelled mid-flight (e.g. due to
  /// encountering an expression that we cannot expand.)
  var isCancelled = false

  init(in context: C, for macro: M, rootedAt effectiveRootNode: Syntax, expectationContextName: TokenSyntax) {
    self.context = context
    self.macro = macro
    self.effectiveRootNode = effectiveRootNode
    self.expectationContextNameExpr = DeclReferenceExprSyntax(baseName: expectationContextName.trimmed)
    super.init()
  }

  /// The number of calls to `_rewrite()` made along the current node hierarchy.
  ///
  /// This value is incremented with each call to `_rewrite()` and managed by
  /// `_visitChild()`.
  private var _rewriteDepth = 0

  /// Rewrite a given syntax node by inserting a call to the expression context
  /// (or rather, its `callAsFunction(_:_:)` member).
  ///
  /// - Parameters:
  ///   - node: The node to rewrite.
  ///   - originalNode: The original node in the original syntax tree, if `node`
  ///     has already been partially rewritten or substituted. If `node` has not
  ///     been rewritten, this argument should equal it.
  ///   - functionName: If not `nil`, the name of the function to call (as a
  ///     member function of the expression context.)
  ///   - additionalArguments: Any additional arguments to pass to the function.
  ///
  /// - Returns: A rewritten copy of `node` that calls into the expression
  ///   context when it is evaluated at runtime.
  private func _rewrite(
    _ node: @autoclosure () -> some ExprSyntaxProtocol,
    originalWas originalNode: @autoclosure () -> some ExprSyntaxProtocol,
    calling functionName: @autoclosure () -> TokenSyntax? = nil,
    passing additionalArguments: @autoclosure () -> [Argument] = []
  ) -> ExprSyntax {
    _rewriteDepth += 1
    if _rewriteDepth > _maximumRewriteDepth {
      // At least _n_ ancestors of this node have already been rewritten, so do
      // not recursively rewrite further. This is necessary to limit the added
      // exponentional complexity we're throwing at the type checker.
      return ExprSyntax(originalNode())
    }

    // We're going to rewrite the node, so we'll evaluate the arguments now.
    let node = node()
    let originalNode = originalNode()
    let functionName = functionName()
    let additionalArguments = additionalArguments()
    rewrittenNodes.insert(Syntax(originalNode))

    let calledExpr: ExprSyntax = if let functionName {
      ExprSyntax(MemberAccessExprSyntax(base: expectationContextNameExpr, name: functionName))
    } else {
      ExprSyntax(expectationContextNameExpr)
    }

    var result = ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: calledExpr,
        leftParen: .leftParenToken(),
        rightParen: .rightParenToken()
      ) {
        LabeledExprSyntax(expression: node.trimmed)
        LabeledExprSyntax(expression: originalNode.expressionID(rootedAt: effectiveRootNode, in: context))
        for argument in additionalArguments {
          LabeledExprSyntax(argument)
        }
      }
    )

    // If the resulting expression has an optional type due to containing an
    // optional chaining expression (e.g. `foo?`) *and* its immediate parent
    // node passes through the syntactical effects of optional chaining, return
    // it as optional-chained so that it parses correctly post-expansion.
    switch node.parent?.kind {
    case .memberAccessExpr, .subscriptCallExpr:
      let optionalChainFinder = _OptionalChainFinder(viewMode: .sourceAccurate)
      optionalChainFinder.walk(node)
      if optionalChainFinder.optionalChainFound {
        result = ExprSyntax(OptionalChainingExprSyntax(expression: result))
      }

    default:
      break
    }

    result.leadingTrivia = originalNode.leadingTrivia
    result.trailingTrivia = originalNode.trailingTrivia

    return result
  }

  /// Rewrite a given syntax node by inserting a call to the expression context
  /// (or rather, its `callAsFunction(_:_:)` member).
  ///
  /// - Parameters:
  ///   - node: The node to rewrite.
  ///   - functionName: If not `nil`, the name of the function to call (as a
  ///     member function of the expression context.)
  ///   - additionalArguments: Any additional arguments to pass to the function.
  ///
  /// - Returns: A rewritten copy of `node` that calls into the expression
  ///   context when it is evaluated at runtime.
  ///
  /// This function is equivalent to `_rewrite(node, originalWas: node)`.
  private func _rewrite(_ node: some ExprSyntaxProtocol, calling functionName: TokenSyntax? = nil, passing additionalArguments: [Argument] = []) -> ExprSyntax {
    _rewrite(node, originalWas: node, calling: functionName, passing: additionalArguments)
  }

  /// Visit `node` as a child of another previously-visited node.
  ///
  /// - Parameters:
  ///   - node: The node to visit.
  ///
  /// - Returns: `node`, or a modified copy thereof if `node` or a child node
  ///   was rewritten.
  ///
  /// Use this function instead of calling `visit(_:)` or `rewrite(_:detach:)`
  /// recursively.
  ///
  /// This overload simply visits `node` and is used for nodes that cannot be
  /// rewritten directly (because they are not expressions.)
  @_disfavoredOverload
  private func _visitChild<S>(_ node: S) -> S where S: SyntaxProtocol {
    rewrite(node, detach: true).cast(S.self)
  }

  /// Visit `node` as a child of another previously-visited node.
  ///
  /// - Parameters:
  ///   - node: The node to visit.
  ///
  /// - Returns: `node`, or a modified copy thereof if `node` or a child node
  ///   was rewritten.
  ///
  /// Use this function instead of calling `visit(_:)` or `rewrite(_:detach:)`
  /// recursively.
  private func _visitChild(_ node: some ExprSyntaxProtocol) -> ExprSyntax {
    let oldRewriteDepth = _rewriteDepth
    defer {
      _rewriteDepth = oldRewriteDepth
    }

    return rewrite(node, detach: true).cast(ExprSyntax.self)
  }

  /// Whether or not the parent node of the given node is capable of containing
  /// a rewritten `DeclReferenceExprSyntax` instance.
  ///
  /// - Parameters:
  ///   - node: The node that might be rewritten. It does not need to be an
  ///     instance of `DeclReferenceExprSyntax`.
  ///
  /// - Returns: Whether or not the _parent_ of `node` will still be
  ///   syntactically valid if `node` is rewritten with `_rewrite(_:)`.
  ///
  /// Instances of `DeclReferenceExprSyntax` are often present in positions
  /// where it would be syntactically invalid to extract them out as function
  /// arguments. This function is used to constrain the cases where we do so to
  /// those we know (or generally know) are "safe".
  private func _isParentOfDeclReferenceExprValidForRewriting(_ node: some SyntaxProtocol) -> Bool {
    guard let parentNode = node.parent else {
      return false
    }

    switch parentNode.kind {
    case .labeledExpr, .functionParameter,
        .prefixOperatorExpr, .postfixOperatorExpr, .infixOperatorExpr,
        .asExpr, .isExpr, .optionalChainingExpr, .forceUnwrapExpr,
        .arrayElement, .dictionaryElement:
      return true
    default:
      return false
    }
  }

  override func visit(_ node: DeclReferenceExprSyntax) -> ExprSyntax {
    // DeclReferenceExprSyntax is used for operator tokens in identifier
    // position. These generally appear when an operator function is passed to
    // a higher-order function (e.g. `sort(by: <)`) and also for the unbounded
    // range expression (`...`). Both are uninteresting to the testing library
    // and can be dropped.
    if node.baseName.isOperator {
      return ExprSyntax(node)
    }

    if _isParentOfDeclReferenceExprValidForRewriting(node) {
      return _rewrite(node)
    }

    // SPECIAL CASE: If this node is the base expression of a member access
    // expression, and that member access expression is the called expression of
    // a function, it is generally safe to extract out (but may need `.self`
    // added to the end.)
    //
    // Module names are an exception to this rule as they cannot be referred to
    // directly in source. So for instance, the following expression will be
    // expanded incorrectly:
    //
    //   #expect(Testing.foo(bar))
    //
    // These sorts of expressions are relatively rare, so we'll allow the bug
    // for the sake of better diagnostics in the common case.
    if node.argumentNames == nil,
       let memberAccessExpr = node.parent?.as(MemberAccessExprSyntax.self),
       ExprSyntax(node) == memberAccessExpr.base,
       let functionCallExpr = memberAccessExpr.parent?.as(FunctionCallExprSyntax.self),
       ExprSyntax(memberAccessExpr) == functionCallExpr.calledExpression {
      // If the base name is an identifier and its first character is uppercase,
      // it is presumably a type name or module name, so don't expand it. (This
      // isn't a great heuristic, but it hopefully minimizes the module name
      // problem above.)
      if case .identifier = node.baseName.tokenKind,
         let firstCharacter = node.baseName.textWithoutBackticks.first, firstCharacter.isUppercase {
        return ExprSyntax(node)
      }

      return _rewrite(
        MemberAccessExprSyntax(
          base: node.trimmed,
          declName: DeclReferenceExprSyntax(baseName: .keyword(.self))
        ),
        originalWas: node
      )
    }

    return ExprSyntax(node)
  }

  override func visit(_ node: TupleExprSyntax) -> ExprSyntax {
    // We are conservative when descending into tuples because they could be
    // tuple _types_ rather than _values_ (e.g. `(Int, Double)`) but those
    // cannot be distinguished with syntax alone.
    if _isParentOfDeclReferenceExprValidForRewriting(node) {
      return _rewrite(
        TupleExprSyntax {
          for element in node.elements {
            _visitChild(element).trimmed
          }
        },
        originalWas: node
      )
    }

    return ExprSyntax(node)
  }

  override func visit(_ node: MemberAccessExprSyntax) -> ExprSyntax {
    if case .keyword = node.declName.baseName.tokenKind {
      // Likely something like Foo.self or X.Type, which we can't reasonably
      // break down further.
      return ExprSyntax(node)
    }

    // As with decl reference expressions, only certain kinds of member access
    // expressions can be directly extracted out.
    if _isParentOfDeclReferenceExprValidForRewriting(node) {
      return _rewrite(
        node.with(\.base, node.base.map(_visitChild)),
        originalWas: node
      )
    }

    return ExprSyntax(node.with(\.base, node.base.map(_visitChild)))
  }

  override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
    _rewrite(
      node
        .with(\.calledExpression, _visitChild(node.calledExpression))
        .with(\.arguments, _visitChild(node.arguments)),
      originalWas: node
    )
  }

  override func visit(_ node: SubscriptCallExprSyntax) -> ExprSyntax {
    _rewrite(
      node
        .with(\.calledExpression, _visitChild(node.calledExpression))
        .with(\.arguments, _visitChild(node.arguments)),
      originalWas: node
    )
  }

  override func visit(_ node: ClosureExprSyntax) -> ExprSyntax {
    // We do not (currently) attempt to descend into closures.
    ExprSyntax(node)
  }

  override func visit(_ node: MacroExpansionExprSyntax) -> ExprSyntax {
    // We do not attempt to descend into freestanding macros.
    ExprSyntax(node)
  }

  override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
    // We do not (currently) attempt to descend into functions.
    DeclSyntax(node)
  }

  // MARK: - Operators

  override func visit(_ node: PrefixOperatorExprSyntax) -> ExprSyntax {
    // Special-case negative number literals as a single expression.
    if node.expression.is(IntegerLiteralExprSyntax.self) || node.expression.is(FloatLiteralExprSyntax.self) {
      if node.operator.tokenKind == .prefixOperator("-") {
        return ExprSyntax(node)
      }
    }

    if node.operator.tokenKind == .prefixOperator("!") {
      // Do not break apart the boolean negation operator from its expression
      // (it adds visual noise but is really just flipping a bit.)
      return _rewrite(node)
    }

    return _rewrite(
      node
        .with(\.expression, _visitChild(node.expression)),
      originalWas: node
    )
  }

  override func visit(_ node: InfixOperatorExprSyntax) -> ExprSyntax {
    if let op = node.operator.as(BinaryOperatorExprSyntax.self)?.operator.textWithoutBackticks,
       op == "==" || op == "!=" || op == "===" || op == "!==" {

      let lhsName = context.makeUniqueClosureParameterName("lhs", in: effectiveRootNode)
      let rhsName = context.makeUniqueClosureParameterName("rhs", in: effectiveRootNode)
      return _rewrite(
        ClosureExprSyntax(
          signature: ClosureSignatureSyntax(
            leadingTrivia: .space,
            parameterClause: .simpleInput(
              ClosureShorthandParameterListSyntax {
                ClosureShorthandParameterSyntax(name: lhsName)
                ClosureShorthandParameterSyntax(name: rhsName)
              }
            ),
            returnClause: ReturnClauseSyntax(
              leadingTrivia: .space,
              type: MemberTypeSyntax(
                leadingTrivia: .space,
                baseType: IdentifierTypeSyntax(name: .identifier("Swift")),
                name: .identifier("Bool")
              ),
              trailingTrivia: .space
            ),
            inKeyword: .keyword(.in),
            trailingTrivia: .space
          )
        ) {
          InfixOperatorExprSyntax(
            leftOperand: DeclReferenceExprSyntax(baseName: lhsName, trailingTrivia: .space),
            operator: BinaryOperatorExprSyntax(text: op),
            rightOperand: DeclReferenceExprSyntax(leadingTrivia: .space, baseName: rhsName, trailingTrivia: .space)
          )
        },
        originalWas: node,
        calling: .identifier("__cmp"),
        passing: [
          Argument(expression: _visitChild(node.leftOperand)),
          Argument(expression: node.leftOperand.expressionID(rootedAt: effectiveRootNode, in: context)),
          Argument(expression: _visitChild(node.rightOperand)),
          Argument(expression: node.rightOperand.expressionID(rootedAt: effectiveRootNode, in: context))
        ]
      )
    }

    return _rewrite(
      node
        .with(\.leftOperand, _visitChild(node.leftOperand))
        .with(\.rightOperand, _visitChild(node.rightOperand)),
      originalWas: node
    )
  }

  override func visit(_ node: InOutExprSyntax) -> ExprSyntax {
    // Swift's Law of Exclusivity means that only one subexpression in the
    // expectation ought to be interacting with `value` when it is passed
    // `inout`, so it should be sufficient to capture it in a `defer` statement
    // that runs after the expression is evaluated.

    let rewrittenExpr = _rewrite(node, calling: .identifier("__inoutAfter"))
    if rewrittenExpr != ExprSyntax(node) {
      let teardownItem = CodeBlockItemSyntax(item: .expr(rewrittenExpr))
      teardownItems.append(teardownItem)
    }

    // The argument should not be expanded in-place as we can't return an
    // argument passed `inout` and expect it to remain semantically correct.
    return ExprSyntax(node)
  }

  // MARK: - Variadics

  override func visit(_ node: PackExpansionExprSyntax) -> ExprSyntax {
    // We cannot expand parameter pack expressions.
    isCancelled = true
    return ExprSyntax(node)
  }

  override func visit(_ node: PackElementExprSyntax) -> ExprSyntax {
    // We cannot expand parameter pack expressions.
    isCancelled = true
    return ExprSyntax(node)
  }

  // MARK: - Casts

  /// Rewrite an `is` or `as?` cast.
  ///
  /// - Parameters:
  ///   - valueExpr: The expression to cast.
  ///   - isAsKeyword: The casting keyword (either `.is` or `.as`).
  ///   - type: The type to cast `valueExpr` to.
  ///   - originalNode: The original `IsExprSyntax` or `AsExprSyntax` node in
  ///     the original syntax tree.
  ///
  /// - Returns: A function call expression equivalent to the described cast.
  private func _rewriteAsCast(_ valueExpr: ExprSyntax, _ isAsKeyword: Keyword, _ type: TypeSyntax, originalWas originalNode: some ExprSyntaxProtocol) -> ExprSyntax {
    rewrittenNodes.insert(Syntax(type))

    return _rewrite(
      _visitChild(valueExpr).trimmed,
      originalWas: originalNode,
      calling: .identifier("__\(isAsKeyword)"),
      passing: [
        Argument(
          expression: MemberAccessExprSyntax(
            base: TupleExprSyntax {
              LabeledExprSyntax(expression: TypeExprSyntax(type: type.trimmed))
            },
            declName: DeclReferenceExprSyntax(baseName: .keyword(.self))
          )
        ),
        Argument(expression: type.expressionID(rootedAt: effectiveRootNode, in: context))
      ]
    )
  }

  override func visit(_ node: AsExprSyntax) -> ExprSyntax {
    switch node.questionOrExclamationMark?.tokenKind {
    case .postfixQuestionMark:
      return _rewriteAsCast(node.expression, .as, node.type, originalWas: node)

    case .exclamationMark where !node.type.isNamed("Bool", inModuleNamed: "Swift") && !node.type.isOptional:
      // Warn that as! will be evaluated before #expect() or #require(), which is
      // probably not what the developer intended. We suppress the warning for
      // casts to Bool and casts to optional types. Presumably such casts are not
      // being performed for their optional-unwrapping behavior, but because the
      // developer knows the type of the expression better than we do.
      context.diagnose(.asExclamationMarkIsEvaluatedEarly(node, in: macro))
      return _rewrite(node)

    case .exclamationMark:
      // Only diagnose for `x as! T`. `x as T` is perfectly fine if it otherwise
      // compiles. For example, `#require(x as Int?)` should compile.
      return _rewrite(node)

    default:
      // This is an "escape hatch" cast. Do not attempt to process the cast.
      return ExprSyntax(node)
    }
  }

  override func visit(_ node: IsExprSyntax) -> ExprSyntax {
    _rewriteAsCast(node.expression, .is, node.type, originalWas: node)
  }

  // MARK: - Literals

  override func visit(_ node: BooleanLiteralExprSyntax) -> ExprSyntax {
    // Contrary to the comment immediately below this function, we *do* rewrite
    // boolean literals so that expressions like `#expect(true)` are expanded.
    _rewrite(node)
  }

  // We don't currently rewrite numeric/string/array/dictionary literals. We
  // could, but it's unclear what the benefit would be and it could seriously
  // impact type checker time.

#if SWT_DELVE_INTO_LITERALS
  override func visit(_ node: IntegerLiteralExprSyntax) -> ExprSyntax {
    _rewrite(node)
  }

  override func visit(_ node: FloatLiteralExprSyntax) -> ExprSyntax {
    _rewrite(node)
  }

  override func visit(_ node: StringLiteralExprSyntax) -> ExprSyntax {
    _rewrite(node)
  }

  override func visit(_ node: ArrayExprSyntax) -> ExprSyntax {
    _rewrite(
      node.with(
        \.elements, ArrayElementListSyntax {
          for element in node.elements {
            ArrayElementSyntax(expression: _visitChild(element.expression).trimmed)
          }
        }
      ),
      originalWas: node
    )
  }

  override func visit(_ node: DictionaryExprSyntax) -> ExprSyntax {
    guard case let .elements(elements) = node.content else {
      return ExprSyntax(node)
    }
    return _rewrite(
      node.with(
        \.content, .elements(
          DictionaryElementListSyntax {
            for element in elements {
              DictionaryElementSyntax(key: _visitChild(element.key).trimmed, value: _visitChild(element.value).trimmed)
            }
          }
        )
      ),
      originalWas: node
    )
  }
#else
  override func visit(_ node: ArrayExprSyntax) -> ExprSyntax {
    return ExprSyntax(node)
  }

  override func visit(_ node: DictionaryExprSyntax) -> ExprSyntax {
    return ExprSyntax(node)
  }
#endif
}

extension ConditionMacro {
  /// Rewrite and expand upon an expression node.
  ///
  /// - Parameters:
  ///   - node: The root of a syntax tree to rewrite. This node may not itself
  ///     be the root of the overall syntax tree—it's just the root of the
  ///     subtree that we're rewriting.
  ///   - expectationContextName: The name of the instance of
  ///     `__ExpectationContext` to call at runtime.
  ///   - macro: The macro expression.
  ///   - effectiveRootNode: The node to treat as the root of the syntax tree
  ///     for the purposes of generating expression ID values.
  ///   - effectKeywordsToApply: The set of effect keywords in the expanded
  ///     expression or its lexical context that may apply to `node`.
  ///   - returnType: The return type of the expanded closure, if statically
  ///     known at macro expansion time.
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: The expanded form of `node` as a closure expression that calls
  ///   the expression context named `expectationContextName` as well as the set
  ///   of rewritten subnodes in `node`, or `nil` if the expression could not be
  ///   rewritten.
  static func rewrite(
    _ node: some ExprSyntaxProtocol,
    usingExpectationContextNamed expectationContextName: TokenSyntax,
    for macro: some FreestandingMacroExpansionSyntax,
    rootedAt effectiveRootNode: some SyntaxProtocol,
    effectKeywordsToApply: Set<Keyword>,
    returnType: (some TypeSyntaxProtocol)?,
    in context: some MacroExpansionContext
  ) -> (ClosureExprSyntax, rewrittenNodes: Set<Syntax>)? {
    _diagnoseTrivialBooleanValue(from: ExprSyntax(node), for: macro, in: context)

    let contextInserter = _ContextInserter(in: context, for: macro, rootedAt: Syntax(effectiveRootNode), expectationContextName: expectationContextName)
    var expandedExpr = contextInserter.rewrite(node, detach: true).cast(ExprSyntax.self)
    if contextInserter.isCancelled {
      return nil
    }
    let rewrittenNodes = contextInserter.rewrittenNodes

    // Insert additional effect keywords/thunks as needed.
    var effectKeywordsToApply = effectKeywordsToApply
    if isThrowing {
      effectKeywordsToApply.insert(.try)
    }
    expandedExpr = applyEffectfulKeywords(effectKeywordsToApply, to: expandedExpr)

    // Construct the body of the closure that we'll pass to the expanded
    // function.
    var codeBlockItems = CodeBlockItemListSyntax {
      if contextInserter.teardownItems.isEmpty {
        expandedExpr.with(\.trailingTrivia, .newline)
      } else {
        // Insert a defer statement that runs any teardown items.
        DeferStmtSyntax {
          for teardownItem in contextInserter.teardownItems {
            teardownItem.with(\.trailingTrivia, .newline)
          }
        }.with(\.trailingTrivia, .newline)

        // If we're inserting any additional code into the closure before
        // the rewritten argument, we can't elide the return keyword.
        ReturnStmtSyntax(
          returnKeyword: .keyword(.return, trailingTrivia: .space),
          expression: expandedExpr,
          trailingTrivia: .space
        )
      }
    }

    // Replace any dollar identifiers in the code block, then construct a
    // capture list for the closure (if needed.)
    var captureList: ClosureCaptureClauseSyntax?
    do {
      let dollarIDReplacer = _DollarIdentifierReplacer()
      codeBlockItems = dollarIDReplacer.rewrite(codeBlockItems, detach: true).cast(CodeBlockItemListSyntax.self)
      if !dollarIDReplacer.dollarIdentifierTokenKinds.isEmpty {
        let dollarIdentifierTokens = dollarIDReplacer.dollarIdentifierTokenKinds.map { tokenKind in
          TokenSyntax(tokenKind, presence: .present)
        }
        captureList = ClosureCaptureClauseSyntax {
          for token in dollarIdentifierTokens {
            ClosureCaptureSyntax(
              name: _rewriteDollarIdentifier(token),
              initializer: InitializerClauseSyntax(
                value: DeclReferenceExprSyntax(baseName: token)
              )
            )
          }
        }
      }
    }

    // Enclose the code block in the final closure.
    let closureExpr = ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        capture: captureList,
        parameterClause: .parameterClause(
          ClosureParameterClauseSyntax(
            parameters: ClosureParameterListSyntax {
              ClosureParameterSyntax(
                firstName: expectationContextName,
                colon: .colonToken(trailingTrivia: .space),
                type: TypeSyntax(
                  MemberTypeSyntax(
                    baseType: IdentifierTypeSyntax(name: .identifier("Testing")),
                    name: .identifier("__ExpectationContext"),
                    genericArgumentClause: returnType.map { returnType in
                      GenericArgumentClauseSyntax {
                        GenericArgumentSyntax(argument: .type(TypeSyntax(returnType)))
                      }
                    }
                  )
                )
              )
            }
          )
        ),
        returnClause: returnType.map { returnType in
          ReturnClauseSyntax(
            arrow: .arrowToken(leadingTrivia: .space, trailingTrivia: .space),
            type: returnType
          )
        },
        inKeyword: .keyword(.in, leadingTrivia: .space, trailingTrivia: .space)
      ),
      statements: codeBlockItems
    )

    return (closureExpr, rewrittenNodes)
  }
}

// MARK: - Finding optional chains

/// A class that walks a syntax tree looking for optional chaining expressions
/// such as `a?.b.c`.
private final class _OptionalChainFinder: SyntaxVisitor {
  /// Whether or not any optional chaining was found.
  var optionalChainFound = false

  override func visit(_ node: OptionalChainingExprSyntax) -> SyntaxVisitorContinueKind {
    optionalChainFound = true
    return .skipChildren
  }
}

// MARK: - Replacing dollar identifiers

/// Rewrite a dollar identifier as a normal (non-dollar) identifier.
///
/// - Parameters:
///   - token: The dollar identifier token to rewrite.
///
/// - Returns: A copy of `token` as an identifier token.
private func _rewriteDollarIdentifier(_ token: TokenSyntax) -> TokenSyntax {
  var result = TokenSyntax.identifier("__renamedCapture__\(token.trimmedDescription)")

  result.leadingTrivia = token.leadingTrivia
  result.trailingTrivia = token.trailingTrivia

  return result
}

/// A syntax rewriter that replaces _numeric_ dollar identifiers (e.g. `$0`)
/// with normal (non-dollar) identifiers.
private final class _DollarIdentifierReplacer: SyntaxRewriter {
  /// The `tokenKind` properties of any dollar identifier tokens that have been
  /// rewritten.
  var dollarIdentifierTokenKinds = Set<TokenKind>()

  override func visit(_ node: TokenSyntax) -> TokenSyntax {
    if case let .dollarIdentifier(id) = node.tokenKind, id.dropFirst().allSatisfy(\.isWholeNumber) {
      // This dollar identifier is numeric, so it's a closure argument.
      dollarIdentifierTokenKinds.insert(node.tokenKind)
      return _rewriteDollarIdentifier(node)
    }

    return node
  }

  override func visit(_ node: ClosureExprSyntax) -> ExprSyntax {
    // Do not recurse into closure expressions because they will have their own
    // argument lists that won't conflict with the enclosing scope's.
    return ExprSyntax(node)
  }
}

// MARK: - Source code capturing

/// Create a dictionary literal expression containing the source code
/// representations of a set of syntax nodes.
///
/// - Parameters:
///   - nodes: The nodes whose source code should be included in the resulting
///     dictionary literal.
///   - effectiveRootNode: The node to treat as the root of the syntax tree
///     for the purposes of generating expression ID values.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: A dictionary literal expression whose keys are expression IDs and
///   whose values are string literals containing the source code of the syntax
///   nodes in `nodes`.
func createDictionaryExpr(forSourceCodeOf nodes: some Sequence<some SyntaxProtocol>, rootedAt effectiveRootNode: some SyntaxProtocol, in context: some MacroExpansionContext) -> DictionaryExprSyntax {
  // Sort the nodes. This isn't strictly necessary for correctness but it does
  // make the produced code more consistent.
  let nodes = nodes.sorted { $0.id < $1.id }

  return DictionaryExprSyntax {
    for node in nodes {
      DictionaryElementSyntax(
        key: node.expressionID(rootedAt: effectiveRootNode, in: context),
        value: StringLiteralExprSyntax(content: node.trimmedDescription)
      )
    }
  }
}

/// Create a dictionary literal expression containing the source code
/// representations of a single syntax node.
///
/// - Parameters:
///   - node: The nodes whose source code should be included in the resulting
///     dictionary literal. This node is treated as the root node.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: A dictionary literal expression containing one key/value pair
///   where the key is the expression ID of `node` and the value is its source
///   code.
func createDictionaryExpr(forSourceCodeOf node: some SyntaxProtocol, in context: some MacroExpansionContext) -> DictionaryExprSyntax {
  createDictionaryExpr(forSourceCodeOf: CollectionOfOne(node), rootedAt: node, in: context)
}
