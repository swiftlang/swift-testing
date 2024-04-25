//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if compiler(>=5.11)
import SwiftSyntax
import SwiftSyntaxMacros
#else
public import SwiftSyntax
public import SwiftSyntaxMacros
#endif

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

  /// Whether or not this attribute specifies arguments to the associated test
  /// function.
  var hasFunctionArguments: Bool {
    otherArguments.lazy
      .compactMap(\.label?.tokenKind)
      .contains(.identifier("arguments"))
  }

  /// Additional arguments passed to the attribute, if any.
  var otherArguments = [Argument]()

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
    // See _SelfRemover for more information. Rewriting a syntax tree discards
    // location information from the copy, so only invoke the rewriter if the
    // `Self` keyword is present somewhere.
    otherArguments = otherArguments.map { argument in
      var expr = argument.expression
      if argument.expression.tokens(viewMode: .sourceAccurate).map(\.tokenKind).contains(.keyword(.Self)) {
        let selfRemover = _SelfRemover(in: context)
        expr = selfRemover.rewrite(Syntax(argument.expression)).cast(ExprSyntax.self)
      }
      return Argument(label: argument.label, expression: expr)
    }

    // Look for any traits in the remaining arguments and slice them off. Traits
    // are the remaining unlabelled arguments. The first labelled argument (if
    // present) is the start of subsequent context-specific arguments.
    if !otherArguments.isEmpty {
      if let labelledArgumentIndex = otherArguments.firstIndex(where: { $0.label != nil }) {
        // There is an argument with a label, so splice there.
        traits = otherArguments[otherArguments.startIndex ..< labelledArgumentIndex].map(\.expression)
        otherArguments = Array(otherArguments[labelledArgumentIndex...])
      } else {
        // No argument has a label, so all the remaining arguments are traits.
        traits = otherArguments.map(\.expression)
        otherArguments.removeAll(keepingCapacity: false)
      }
    }

    // Combine traits from other sources (leading comments and availability
    // attributes) if applicable.
    traits += createCommentTraitExprs(for: declaration)
    if let declaration = declaration.asProtocol((any WithAttributesSyntax).self) {
      traits += createAvailabilityTraitExprs(for: declaration, in: context)
    }
    diagnoseIssuesWithTraits(in: traits, addedTo: attribute, in: context)

    // Use the start of the test attribute's name as the canonical source
    // location of the test.
    sourceLocation = createSourceLocationExpr(of: attribute.attributeName, context: context)
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
      for traitExpr in traits {
        ArrayElementSyntax(expression: traitExpr)
      }
    }))

    var otherArguments = self.otherArguments

    // Any arguments of the test declaration macro which specify test arguments
    // need to be wrapped a closure so they may be evaluated lazily by the
    // testing library at runtime. If any such arguments are present, they will
    // begin with a labeled argument named `arguments:` and include all
    // subsequent unlabeled arguments.
    if let argumentsIndex = otherArguments.firstIndex(where: { $0.label?.tokenKind == .identifier("arguments") }) {
      for index in argumentsIndex ..< otherArguments.endIndex {
        var argument = otherArguments[index]
        argument.expression = .init(ClosureExprSyntax { argument.expression })
        otherArguments[index] = argument
      }
    }

    arguments += otherArguments
    arguments.append(Argument(label: "sourceLocation", expression: sourceLocation))

    return LabeledExprListSyntax(arguments)
  }
}
