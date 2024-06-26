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

/// A type describing an argument to a function, closure, etc.
///
/// This type is used as an intermediate form before being converted to an
/// instance of `LabeledExprSyntax`, `ClosureParameterSyntax`, etc.
///
/// - Bug: This type is needed because trimming a syntax node or copying it into
///   another node erases its source location information, so we cannot convert
///   expressions to `LabeledExprSyntax` instances until we no longer need that
///   information. ([swift-syntax-#1961](https://github.com/swiftlang/swift-syntax/issues/1961))
struct Argument {
  /// The argument's label, if present.
  var label: TokenSyntax?

  /// The argument expression.
  var expression: ExprSyntax

  init(label: TokenSyntax? = nil, expression: ExprSyntax) {
    self.label = label
    self.expression = expression
  }

  init(label: TokenSyntax? = nil, expression: some ExprSyntaxProtocol) {
    self.label = label
    self.expression = ExprSyntax(expression)
  }

  /// Initialize an instance of this type from a labeled expression.
  ///
  /// - Parameters:
  ///   - labeledExpr: The labeled expression.
  ///
  /// The resulting instance of ``Argument`` preserves any source location
  /// information present in `labeledExpr`.
  init(_ labeledExpr: LabeledExprSyntax) {
    self.init(label: labeledExpr.label, expression: labeledExpr.expression)
  }

  /// Initialize an instance of this type from an additional (i.e. labelled)
  /// trailing closure.
  ///
  /// - Parameters:
  ///   - trailingClosure: The trailing closure.
  ///
  /// The resulting instance of ``Argument`` preserves any source location
  /// information present in `trailingClosure`.
  init(_ trailingClosure: MultipleTrailingClosureElementSyntax) {
    self.init(label: trailingClosure.label, expression: trailingClosure.closure)
  }
}

// MARK: -

extension LabeledExprSyntax {
  /// Initialize an instance of this type from an instance of ``Argument``.
  ///
  /// - Parameters:
  ///   - argument: The argument to cast.
  ///
  /// The resulting instance of `LabeledExprSyntax` does _not_ preserve any
  /// source location information present in `argument`.
  init(_ argument: Argument) {
    self.init(label: argument.label?.text, expression: argument.expression.trimmed)
  }
}

// MARK: -

extension LabeledExprListSyntax {
  /// Initialize an instance of this type from a sequence of ``Argument``
  /// instances.
  ///
  /// - Parameters:
  ///   - arguments: The arguments to include in the resulting expression.
  ///
  /// The resulting instance of `LabeledExprListSyntax` is suitable for
  /// passing as arguments to a function such as `__check()`. It does not
  /// include leading or trailing parentheses, nor a final trailing comma.
  init(_ arguments: some Sequence<Argument>) {
    self.init {
      for labeledExpr in arguments.lazy.map(LabeledExprSyntax.init) {
        labeledExpr
      }
    }
  }
}
