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

  /// Test arguments passed to a parameterized test function, if any.
  ///
  /// When non-`nil`, the value of this property is an array beginning with the
  /// argument passed to this attribute for the parameter labeled `arguments:`
  /// followed by all of the remaining, unlabeled arguments.
  var testFunctionArguments: [Argument]?

  /// Whether or not this attribute specifies arguments to the associated test
  /// function.
  var hasFunctionArguments: Bool {
    testFunctionArguments != nil
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

    var nonDisplayNameArguments: [Argument] = []
    if let arguments = attribute.arguments, case let .argumentList(argumentList) = arguments {
      // If the first argument is an unlabelled string literal, it's the display
      // name of the test or suite. If it's anything else, including a nil
      // literal, the test does not have a display name.
      if let firstArgument = argumentList.first {
        let firstArgumentHasLabel = (firstArgument.label != nil)
        if !firstArgumentHasLabel, let stringLiteral = firstArgument.expression.as(StringLiteralExprSyntax.self) {
          displayName = stringLiteral
          nonDisplayNameArguments = argumentList.dropFirst().map(Argument.init)
        } else if !firstArgumentHasLabel, firstArgument.expression.is(NilLiteralExprSyntax.self) {
          nonDisplayNameArguments = argumentList.dropFirst().map(Argument.init)
        } else {
          nonDisplayNameArguments = argumentList.map(Argument.init)
        }
      }
    }

    // Remove leading "Self." expressions from the arguments of the attribute.
    // See _SelfRemover for more information. Rewriting a syntax tree discards
    // location information from the copy, so only invoke the rewriter if the
    // `Self` keyword is present somewhere.
    nonDisplayNameArguments = nonDisplayNameArguments.map { argument in
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
    if !nonDisplayNameArguments.isEmpty {
      if let labelledArgumentIndex = nonDisplayNameArguments.firstIndex(where: { $0.label != nil }) {
        // There is an argument with a label, so splice there.
        traits = nonDisplayNameArguments[nonDisplayNameArguments.startIndex ..< labelledArgumentIndex].map(\.expression)
        testFunctionArguments = Array(nonDisplayNameArguments[labelledArgumentIndex...])
      } else {
        // No argument has a label, so all the remaining arguments are traits.
        traits = nonDisplayNameArguments.map(\.expression)
      }
    }

    // If this attribute is attached to a parameterized test function, augment
    // the argument expressions with explicit type information based on the
    // parameters of the function signature to help the type checker infer the
    // types of passed-in collections correctly.
    if let testFunctionArguments, let functionDecl = declaration.as(FunctionDeclSyntax.self) {
      self.testFunctionArguments = testFunctionArguments.testArguments(typedUsingParameters: functionDecl.signature.parameterClause.parameters)
    }

    // Combine traits from other sources (leading comments and availability
    // attributes) if applicable.
    traits += createCommentTraitExprs(for: declaration)
    if let declaration = declaration.asProtocol((any WithAttributesSyntax).self) {
      traits += createAvailabilityTraitExprs(for: declaration, in: context)
    }

    // Use the start of the test attribute's name as the canonical source
    // location of the test.
    sourceLocation = createSourceLocationExpr(of: attribute.attributeName, context: context)

    // After this instance is fully initialized, diagnose known issues.
    diagnoseIssuesWithTraits(in: context)
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
        ArrayElementSyntax(expression: traitExpr).trimmed
      }
    }))

    // If there are any parameterized test function arguments, wrap each in a
    // closure so they may be evaluated lazily at runtime.
    if let testFunctionArguments {
      arguments += testFunctionArguments.map { argument in
        var copy = argument
        copy.expression = .init(ClosureExprSyntax { argument.expression.trimmed })
        return copy
      }
    }

    arguments.append(Argument(label: "sourceLocation", expression: sourceLocation))

    return LabeledExprListSyntax(arguments)
  }
}

extension Collection<Argument> {
  /// This collection of test function arguments augmented with explicit type
  /// information based on the specified function parameters, if appropriate.
  ///
  /// - Parameters:
  ///   - parameters: The parameters of the function to which this collection of
  ///     test arguments was passed.
  ///
  /// - Returns: An array containing this collection of test arguments with
  ///   any array literal expressions given explicit type information via an
  ///   `as ...` cast.
  fileprivate func testArguments(typedUsingParameters parameters: FunctionParameterListSyntax) -> [Argument] {
    if count == 1 {
      let tupleTypes = parameters.lazy
        .map(\.type)
        .map(String.init(describing:))
        .joined(separator: ",")

      return map { argument in
        // Only add explicit types below if this is an Array literal expression.
        guard argument.expression.is(ArrayExprSyntax.self) else {
          return argument
        }

        var argument = argument
        argument.expression = "\(argument.expression) as [(\(raw: tupleTypes))]"
        return argument
      }
    } else {
      return zip(self, parameters)
        .map { argument, parameter in
          // Only add explicit types below if this is an Array literal
          // expression.
          guard argument.expression.is(ArrayExprSyntax.self) else {
            return argument
          }

          var argument = argument
          argument.expression = .init(AsExprSyntax(expression: argument.expression, type: ArrayTypeSyntax(element: parameter.type)))
          return argument
        }
    }
  }
}
