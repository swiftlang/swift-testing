//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Finding effect keywords and expressions

/// A syntax visitor class that looks for effectful keywords in a given
/// expression.
private final class _EffectFinder: SyntaxAnyVisitor {
  /// The effect keywords discovered so far.
  var effectKeywords: Set<Keyword> = []

  override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
    switch node.kind {
    case .tryExpr:
      effectKeywords.insert(.try)
    case .awaitExpr:
      effectKeywords.insert(.await)
    case .consumeExpr:
      effectKeywords.insert(.consume)
    case .borrowExpr:
      effectKeywords.insert(.borrow)
    case .unsafeExpr:
      effectKeywords.insert(.unsafe)
    case .closureExpr, .functionDecl:
      // Do not delve into closures or function declarations.
      return .skipChildren
    case .variableDecl:
      // Delve into variable declarations.
      return .visitChildren
    default:
      // Do not delve into declarations other than variables.
      if node.isProtocol((any DeclSyntaxProtocol).self) {
        return .skipChildren
      }
    }

    // Recurse into everything else.
    return .visitChildren
  }
}

/// Find effectful keywords in a syntax node.
///
/// - Parameters:
///   - node: The node to inspect.
///   - context: The macro context in which the expression is being parsed.
///
/// - Returns: A set of effectful keywords such as `await` that are present in
///   `node`.
///
/// This function does not descend into function declarations or closure
/// expressions because they represent distinct lexical contexts and their
/// effects are uninteresting in the context of `node` unless they are called.
func findEffectKeywords(in node: some SyntaxProtocol, context: some MacroExpansionContext) -> Set<Keyword> {
  // TODO: gather any effects from the lexical context once swift-syntax-#3037 and related PRs land
  let effectFinder = _EffectFinder(viewMode: .sourceAccurate)
  effectFinder.walk(node)
  return effectFinder.effectKeywords
}

extension BidirectionalCollection<Syntax> {
  /// The suffix of syntax nodes in this collection which are effectful
  /// expressions, such as those for `try` or `await`.
  var trailingEffectExpressions: some Collection<Syntax> {
    reversed()
      .prefix { node in
        // This could be simplified if/when swift-syntax introduces a protocol
        // which all effectful expression syntax node types conform to.
        // See https://github.com/swiftlang/swift-syntax/issues/3040
        node.is(TryExprSyntax.self) || node.is(AwaitExprSyntax.self) || node.is(UnsafeExprSyntax.self)
      }
      .reversed()
  }
}

// MARK: - Inserting effect keywords/thunks

/// Whether or not the `unsafe` expression keyword is supported.
var isUnsafeKeywordSupported: Bool {
  // The 'unsafe' keyword was introduced in 6.2 as part of SE-0458. Older
  // toolchains are not aware of it.
#if compiler(>=6.2)
  true
#else
  false
#endif
}

/// Make a function call expression to an effectful thunk function provided by
/// the testing library.
///
/// - Parameters:
///   - thunkName: The unqualified name of the thunk function to call. This
///     token must be the name of a function in the `Testing` module.
///   - expr: The expression to thunk.
///
/// - Returns: An expression representing a call to the function named
///   `thunkName`, passing `expr`.
private func _makeCallToEffectfulThunk(_ thunkName: TokenSyntax, passing expr: some ExprSyntaxProtocol) -> ExprSyntax {
  ExprSyntax(
    FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("Testing")),
        declName: DeclReferenceExprSyntax(baseName: thunkName)
      ),
      leftParen: .leftParenToken(),
      rightParen: .rightParenToken()
    ) {
      LabeledExprSyntax(expression: expr.trimmed)
    }
  )
}

/// Apply the given effectful keywords (i.e. `try` and `await`) to an expression
/// using thunk functions provided by the testing library.
///
/// - Parameters:
///   - effectfulKeywords: The effectful keywords to apply.
///   - expr: The expression to apply the keywords and thunk functions to.
///
/// - Returns: A copy of `expr` if no changes are needed, or an expression that
///   adds the keywords in `effectfulKeywords` to `expr`.
func applyEffectfulKeywords(_ effectfulKeywords: Set<Keyword>, to expr: some ExprSyntaxProtocol) -> ExprSyntax {
  let originalExpr = expr
  var expr = ExprSyntax(expr.trimmed)

  let needAwait = effectfulKeywords.contains(.await) && !expr.is(AwaitExprSyntax.self)
  let needTry = effectfulKeywords.contains(.try) && !expr.is(TryExprSyntax.self)

  let needUnsafe = isUnsafeKeywordSupported && effectfulKeywords.contains(.unsafe) && !expr.is(UnsafeExprSyntax.self)

  // First, add thunk function calls.
  if needAwait {
    expr = _makeCallToEffectfulThunk(.identifier("__requiringAwait"), passing: expr)
  }
  if needTry {
    expr = _makeCallToEffectfulThunk(.identifier("__requiringTry"), passing: expr)
  }
  if needUnsafe {
    expr = _makeCallToEffectfulThunk(.identifier("__requiringUnsafe"), passing: expr)
  }

  // Then add keyword expressions. (We do this separately so we end up writing
  // `try await __r(__r(self))` instead of `try __r(await __r(self))` which is
  // less accepted by the compiler.)
  if needAwait {
    expr = ExprSyntax(
      AwaitExprSyntax(
        awaitKeyword: .keyword(.await).with(\.trailingTrivia, .space),
        expression: expr
      )
    )
  }
  if needTry {
    expr = ExprSyntax(
      TryExprSyntax(
        tryKeyword: .keyword(.try).with(\.trailingTrivia, .space),
        expression: expr
      )
    )
  }
  if needUnsafe {
    expr = ExprSyntax(
      UnsafeExprSyntax(
        unsafeKeyword: .keyword(.unsafe).with(\.trailingTrivia, .space),
        expression: expr
      )
    )
  }

  expr.leadingTrivia = originalExpr.leadingTrivia
  expr.trailingTrivia = originalExpr.trailingTrivia

  return expr
}
