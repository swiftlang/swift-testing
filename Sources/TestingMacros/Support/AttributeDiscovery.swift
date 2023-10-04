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
import SwiftSyntaxMacros

/// A syntax rewriter that removes leading `Self.` tokens from member access
/// expressions in a syntax tree.
///
/// If the developer specified Self.something as an argument to the `@Test` or
/// `@Suite` attribute, we will currently incorrectly infer Self as equalling
/// the `__TestContainer` type we emit rather than the type containing the
/// test. This class strips off `Self.` wherever that occurs.
///
/// Note that this operation is technically incorrect if a subexpression of the
/// attribute declares a type and refers to it with `Self`. We accept this
/// constraint as it is unlikely to pose real-world issues and is generally
/// solvable by using an explicit type name instead of `Self`.
///
/// This class should instead replace `Self` with the name of the containing
/// type when rdar://105470382 is resolved.
private final class _SelfRemover<C>: SyntaxRewriter where C: MacroExpansionContext {
  /// The macro context in which the expression is being parsed.
  let context: C

  /// Initialize an instance of this class.
  ///
  /// - Parameters:
  ///   - context: The macro context in which the expression is being parsed.
  ///   - viewMode: The view mode to use when walking the syntax tree.
  init(in context: C) {
    self.context = context
  }

  override func visit(_ node: MemberAccessExprSyntax) -> ExprSyntax {
    if let base = node.base?.as(DeclReferenceExprSyntax.self) {
      if base.baseName.tokenKind == .keyword(.Self) {
        // We cannot currently correctly convert Self.self into the expected
        // type name, but once rdar://105470382 is resolved we can replace the
        // base expression with the typename here (at which point Self.self
        // ceases to be an interesting case anyway.)
        return ExprSyntax(node.declName)
      }
    } else if let base = node.base?.as(MemberAccessExprSyntax.self) {
      return ExprSyntax(node.with(\.base, visit(base)))
    }
    return ExprSyntax(node)
  }
}

/// A type describing information parsed from a `@Test` or `@Suite` attribute.
struct AttributeInfo {
  /// The attribute node that was parsed to produce this instance.
  var attribute: AttributeSyntax

  /// The display name of the attribute, if present.
  var displayName: StringLiteralExprSyntax?

  /// The traits applied to the attribute, if any.
  var traits = [ExprSyntax]()

  /// Parameterized arguments to the test function, if any.
  var functionArguments = [Argument]()

  /// Additional arguments passed to the attribute, if any.
  var otherArguments = [Argument]()

  private static func _splitArgumentsAtLabel(_ arguments: some BidirectionalCollection<Argument>) -> (before: [Argument], after: [Argument]) {
    let labelledArgumentIndex = arguments.firstIndex(where: { $0.label != nil }) ?? arguments.endIndex
    return (
      Array(arguments[arguments.startIndex ..< labelledArgumentIndex]),
      Array(arguments[labelledArgumentIndex...])
    )
  }

  /// The source location of the attribute.
  ///
  /// When parsing, the testing library uses the start of the attribute's name
  /// as the canonical source location of the test or suite.
  var sourceLocation: ExprSyntax

  /// Create an instance of this type by parsing a `@Test` or `@Suite`
  /// attribute.
  ///
  /// - Parameters:
  ///   - attribute: The attribute whose arguments should be extracted. If this
  ///     attribute is not a `@Test` or `@Suite` attribute, the result is
  ///     unspecified.
  ///   - declaration: The declaration to which `attribute` is attached. For
  ///     technical reasons, this argument is only constrained to
  ///     `SyntaxProtocol`, however an instance of a type conforming to
  ///     `DeclSyntaxProtocol & WithAttributesSyntax` is expected.
  ///   - context: The macro context in which the expression is being parsed.
  init(byParsing attribute: AttributeSyntax, on declaration: some SyntaxProtocol, in context: some MacroExpansionContext) {
    self.attribute = attribute

    if let arguments = attribute.arguments, case let .argumentList(argumentList) = arguments {
      // If the first argument is an unlabelled string literal, it's the display
      // name of the test or suite. If it's anything else, including a nil
      // literal, the test does not have a display name.
      if let firstArgument = argumentList.first {
        let firstArgumentHasLabel = (firstArgument.label != nil)
        if !firstArgumentHasLabel, let stringLiteral = firstArgument.expression.as(StringLiteralExprSyntax.self) {
          displayName = stringLiteral
          otherArguments = argumentList.dropFirst().map(Argument.init)
        } else if !firstArgumentHasLabel, firstArgument.expression.is(NilLiteralExprSyntax.self) {
          otherArguments = argumentList.dropFirst().map(Argument.init)
        } else {
          otherArguments = argumentList.map(Argument.init)
        }
      }
    }

    // Remove leading "Self." expressions from the arguments of the attribute.
    // See _SelfRemover for more information.
    let selfRemover = _SelfRemover(in: context)
    otherArguments = zip(otherArguments, otherArguments.lazy.map(\.expression)).lazy
      .map { ($0, selfRemover.rewrite(Syntax($1))) }
      .map { ($0, $1.cast(ExprSyntax.self)) }
      .map { Argument(label: $0.label, expression: $1) }

    // Look for any traits in the remaining arguments and slice them off. Traits
    // are the remaining unlabelled arguments. The first labelled argument (if
    // present) is the start of subsequent context-specific arguments.
    if !otherArguments.isEmpty {
      let splitArguments = Self._splitArgumentsAtLabel(otherArguments)
      traits = splitArguments.before.map(\.expression)
      otherArguments = splitArguments.after
    }

    // Combine traits from other sources (leading comments and availability
    // attributes) if applicable.
    traits += createCommentTraitExprs(for: declaration)
    if let declaration = declaration.asProtocol((any WithAttributesSyntax).self) {
      traits += createAvailabilityTraitExprs(for: declaration, in: context)
    }

    // Look for any parameterized arguments and splice them out. This logic is
    // similar to, but not identical to, the logic to split out traits because
    // the first parameterized argument *does* have a label, but the first trait
    // does not have one.
    if let firstOtherArgument = otherArguments.first, firstOtherArgument.label?.tokenKind == .identifier("arguments") {
      let splitArguments = Self._splitArgumentsAtLabel(otherArguments.dropFirst())
      functionArguments = CollectionOfOne(firstOtherArgument) + splitArguments.before
      otherArguments = splitArguments.after
    }

    // Use the start of the test attribute's name as the canonical source
    // location of the test.
    sourceLocation = createSourceLocationExpr(of: attribute.attributeName, context: context)
  }

  /// Expand any statically-discoverable tags in this instance's ``traits``
  /// property to include their source code representations.
  ///
  /// - Parameters:
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: A copy of ``traits`` with any statically discoverable tags
  ///   expanded to include their source code representations.
  private func _traitExprsWithExpandedTags(in context: some MacroExpansionContext) -> [ExprSyntax] {
    traits.lazy.map { trait in
      guard let functionCall = trait.as(FunctionCallExprSyntax.self),
            let calledExpression = functionCall.calledExpression.as(MemberAccessExprSyntax.self) else {
        return trait
      }

      switch calledExpression.tokens(viewMode: .fixedUp).map(\.textWithoutBackticks).joined() {
      case ".tags", "Tag.List.tags", "Testing.Tag.List.tags":
        let tags = functionCall.arguments.lazy
          .map(\.expression)
          .flatMap { tag in
            // Flatten any array literals present in .tags(). For example:
            // @Test(..., .tags(["A", "B"]), .tags("C")) -> ["A", "B", "C"]
            if let tagArray = tag.as(ArrayExprSyntax.self) {
              return tagArray.elements.map(\.expression)
            }
            return [tag]
          }
        let tagArguments = tags.lazy
          .map(\.trimmed)
          .map { tag -> ExprSyntax in
            switch tag.kind {
            case .memberAccessExpr, .functionCallExpr:
              let sourceCodeExpr = createSourceCodeExpr(from: tag)
              return "Testing.Tag.__tag(\(tag), sourceCode: \(sourceCodeExpr))"
            default:
              return tag
            }
          }.map { Argument(expression: $0) }

        return "Testing.Tag.List.tags(\(LabeledExprListSyntax(tagArguments)))"
      default:
        break
      }

      // The called expression did not match a pattern we recognize.
      return trait
    }
  }

  private func _cartesianProduct(of collectionArguments: [Argument]) -> ExprSyntax {
    if collectionArguments.isEmpty {
      preconditionFailure("Passed empty parameterized arguments array to \(#function)")
    }

    let closureArgsExpr = ClosureShorthandParameterListSyntax {
      for i in 0 ..< collectionArguments.count {
        ClosureShorthandParameterSyntax(name: .identifier("__collection\(i)"))
      }
    }
    let resultTupleExpr = TupleExprSyntax {
      for i in 0 ..< collectionArguments.count {
        LabeledExprSyntax(expression: "__arg\(raw: i)" as ExprSyntax)
      }
    }

    let lastIndex = collectionArguments.count - 1
    var mappingExpr: ExprSyntax = """
      __collection\(raw: lastIndex).lazy.map { __arg\(raw: lastIndex) in
        \(resultTupleExpr)
      }
    """
    for (index, _) in collectionArguments.enumerated().reversed().dropFirst() {
      mappingExpr = """
      __collection\(raw: index).lazy.flatMap { __arg\(raw: index) in
        \(mappingExpr)
      }
      """
    }

    let cartesianProductExpr: ExprSyntax = """
    __cartesianProduct(\(LabeledExprListSyntax(collectionArguments))) { \(closureArgsExpr) in
      \(mappingExpr)
    }
    """
    return cartesianProductExpr.formatted().cast(ExprSyntax.self)
  }

  /// Convert this instance to a series of arguments suitable for passing to a
  /// function like `.__type()` or `.__function()`.
  ///
  /// - Parameters:
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: A copy of `self`, converted to one or more function argument
  ///   syntax nodes.
  func functionArgumentList(in context: some MacroExpansionContext) -> LabeledExprListSyntax {
    var arguments = [Argument]()

    if let displayName {
      arguments.append(Argument(label: .identifier("displayName"), expression: displayName))
    }
    arguments.append(Argument(label: .identifier("traits"), expression: ArrayExprSyntax {
      for traitExpr in _traitExprsWithExpandedTags(in: context) {
        ArrayElementSyntax(expression: traitExpr)
      }
    }))
    switch functionArguments.count {
    case 0:
      break
    case 1:
      arguments += functionArguments
    default:
      arguments.append(Argument(label: "arguments", expression: _cartesianProduct(of: functionArguments)))
    }
    arguments += otherArguments
    arguments.append(Argument(label: "sourceLocation", expression: sourceLocation))

    return LabeledExprListSyntax(arguments)
  }
}
