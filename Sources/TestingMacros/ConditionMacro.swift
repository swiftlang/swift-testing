//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftParser
public import SwiftSyntax
import SwiftSyntaxBuilder
public import SwiftSyntaxMacros

#if !hasFeature(SymbolLinkageMarkers) && SWT_NO_LEGACY_TEST_DISCOVERY
#error("Platform-specific misconfiguration: either SymbolLinkageMarkers or legacy test discovery is required to expand #expect(exitsWith:)")
#endif

/// A protocol containing the common implementation for the expansions of the
/// `#expect()` and `#require()` macros.
///
/// This type is used to implement the `#expect()` and `#require()` macros. Do
/// not use it directly.
///
/// ## Macro arguments
///
/// Overloads of these macros that evaluate an expression take exactly three
/// arguments: a "condition" argument, a `Comment?`-typed argument with no
/// label, and an optional `SourceLocation`-typed argument with the label
/// `sourceLocation`. The "condition" argument may be expanded into additional
/// arguments based on its representation in the syntax tree.
///
/// ## Macro arguments with trailing closures
///
/// Overloads of these macros that take trailing closures are expected to use
/// the label `"performing"` to identify the (first) trailing closure. By using
/// a consistent label, we can eliminate ambiguity during parsing.
///
/// The `__check()` function that implements expansions of these macros must
/// take any developer-supplied arguments _before_ the ones inserted during
/// macro expansion (starting with the `"expression"` argument.) The `isolation`
/// argument (if present) and `sourceLocation` argument are placed at the end of
/// the generated function call's argument list.
public protocol ConditionMacro: ExpressionMacro, Sendable {
  /// Whether or not the macro's expansion may throw an error.
  static var isThrowing: Bool { get }

  /// The return type of the expansion's closure, if it can be statically
  /// determined.
  ///
  /// This property is ignored when a condition macro is closure-based.
  static var returnType: TypeSyntax? { get }
}

// MARK: -

/// The token used as the label of the argument passed to `#expect()` and
/// `#require()` and used for actor isolation.
private var _isolationLabel: TokenSyntax { .identifier("isolation") }

/// The token used as the label of the source location argument passed to
/// `#expect()` and `#require()`.
private var _sourceLocationLabel: TokenSyntax { .identifier("sourceLocation") }

/// The token used as a mandatory label on any (first) trailing closure used
/// with `#expect()` or `#require()`.
private var _trailingClosureLabel: TokenSyntax { .identifier("performing") }

extension ConditionMacro {
  public static func expansion(
    of macro: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    return try expansion(of: macro, primaryExpression: nil, in: context)
  }

  public static var formatMode: FormatMode {
    .disabled
  }

  public static var returnType: TypeSyntax? {
    TypeSyntax(
      MemberTypeSyntax(
        baseType: IdentifierTypeSyntax(name: .identifier("Swift")),
        name: .identifier("Bool")
      )
    )
  }

  /// Perform the expansion of this condition macro.
  ///
  /// - Parameters:
  ///   - macro: The macro to expand.
  ///   - primaryExpression: The expression to use for source code capture, or
  ///     `nil` to infer it from `macro`.
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: The expanded form of `macro`.
  ///
  /// - Throws: Any error preventing expansion of `macro`.
  static func expansion(
    of macro: some FreestandingMacroExpansionSyntax,
    primaryExpression: ExprSyntax?,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    // Reconstruct an argument list that includes any trailing closures.
    let macroArguments = argumentList(of: macro, in: context)

    // Figure out important argument indices.
    let trailingClosureIndex = macroArguments.firstIndex { $0.label?.tokenKind == _trailingClosureLabel.tokenKind }
    var commentIndex: [Argument].Index?
    if let trailingClosureIndex {
      // Assume that the comment, if present is the last argument in the
      // argument list prior to the trailing closure that has no label.
      commentIndex = macroArguments[..<trailingClosureIndex].lastIndex { $0.label == nil }
    } else if macroArguments.count > 1 {
      // If there is no trailing closure argument and there is more than one
      // argument, then the comment is the last argument with no label (and also
      // never the first argument.)
      commentIndex = macroArguments.dropFirst().lastIndex { $0.label == nil }
    }
    let isolationArgumentIndex = macroArguments.lazy
      .compactMap(\.label)
      .firstIndex { $0.tokenKind == _isolationLabel.tokenKind }
    let sourceLocationArgumentIndex = macroArguments.lazy
      .compactMap(\.label)
      .firstIndex { $0.tokenKind == _sourceLocationLabel.tokenKind }

    // Construct the argument list to __check().
    var expandedFunctionName = TokenSyntax.identifier("__checkCondition")
    var checkArguments = [Argument]()
    var effectKeywordsToApply: Set<Keyword> = []
    do {
      if let trailingClosureIndex {
        expandedFunctionName = .identifier("__checkClosureCall")

        // Include all arguments other than the "comment" and "sourceLocation"
        // arguments here.
        checkArguments += macroArguments.indices.lazy
          .filter { $0 != commentIndex }
          .filter { $0 != isolationArgumentIndex }
          .filter { $0 != sourceLocationArgumentIndex }
          .map { macroArguments[$0] }

        // The trailing closure should be the focus of the source code capture.
        let primaryExpression = primaryExpression ?? macroArguments[trailingClosureIndex].expression
        let nodeForSourceCodeArgument: Syntax
        if let closureExpr = primaryExpression.as(ClosureExprSyntax.self),
           closureExpr.signature == nil && closureExpr.statements.count == 1,
           let item = closureExpr.statements.first?.item {
          // TODO: capture closures as a different kind of Testing.Expression
          // with a separate subexpression per code item.

          // If a closure contains a single statement or declaration, we can't
          // meaningfully break it down as an expression, but we can still
          // capture its source representation.
          nodeForSourceCodeArgument = Syntax(item)
        } else {
          nodeForSourceCodeArgument = Syntax(primaryExpression)
        }
        checkArguments.append(
          Argument(
            label: "sourceCode",
            expression: createDictionaryExpr(forSourceCodeOf: nodeForSourceCodeArgument)
          )
        )

      } else if let firstArgument = macroArguments.first {
        let originalArgumentExpr = firstArgument.expression
        effectKeywordsToApply = findEffectKeywords(in: originalArgumentExpr)

        var useEscapeHatch = false
        if let asExpr = originalArgumentExpr.as(AsExprSyntax.self), asExpr.questionOrExclamationMark == nil {
          // "Escape hatch" for x as Bool to avoid the full recursive expansion.
          useEscapeHatch = true
        } else if effectKeywordsToApply.contains(.consume) {
          // `consume` expressions imply non-copyable values which cannot yet be
          // safely used with the closure we generate below.
          useEscapeHatch = true
        }

        if useEscapeHatch {
          expandedFunctionName = .identifier("__checkEscapedCondition")

          checkArguments.append(firstArgument)
          checkArguments.append(
            Argument(
              label: "sourceCode",
              expression: createDictionaryExpr(forSourceCodeOf: originalArgumentExpr)
            )
          )

        } else {
          if effectKeywordsToApply.contains(.await) {
            expandedFunctionName = .identifier("__checkConditionAsync")
          }

          let expressionContextName = context.makeUniqueClosureParameterName("__ec", in: originalArgumentExpr)
          let (closureExpr, rewrittenNodes) = rewrite(
            originalArgumentExpr,
            usingExpressionContextNamed: expressionContextName,
            for: macro,
            rootedAt: originalArgumentExpr,
            effectKeywordsToApply: effectKeywordsToApply,
            returnType: returnType,
            in: context
          )
          checkArguments.append(Argument(expression: closureExpr))

          checkArguments.append(
            Argument(
              label: "sourceCode",
              expression: createDictionaryExpr(
                forSourceCodeOf: rewrittenNodes,
                rootedAt: originalArgumentExpr
              )
            )
          )
        }

        // Include all arguments other than the "condition", "comment", and
        // "sourceLocation" arguments here.
        checkArguments += macroArguments.dropFirst().indices.lazy
          .filter { $0 != commentIndex }
          .filter { $0 != isolationArgumentIndex }
          .filter { $0 != sourceLocationArgumentIndex }
          .map { macroArguments[$0] }
      }

      // Capture any comments as well (either in source or as a macro argument.)
      let commentsArrayExpr = ArrayExprSyntax {
        for commentTraitExpr in createCommentTraitExprs(for: macro) {
          ArrayElementSyntax(expression: commentTraitExpr)
        }
        if let commentIndex {
          ArrayElementSyntax(expression: macroArguments[commentIndex].expression.trimmed)
        }
      }
      if let commentIndex, !macroArguments[commentIndex].expression.is(StringLiteralExprSyntax.self) {
        // The developer supplied a comment argument that isn't a string
        // literal. It might be nil, so explicitly filter out nil values from
        // the resulting comment array.
        checkArguments.append(Argument(
          label: "comments",
          expression: #"(\#(commentsArrayExpr) as [Comment?]).compactMap(\.self)"#
        ))
      } else {
        checkArguments.append(Argument(label: "comments", expression: commentsArrayExpr))
      }

      checkArguments.append(Argument(label: "isRequired", expression: BooleanLiteralExprSyntax(isThrowing)))

      if let isolationArgumentIndex {
        checkArguments.append(macroArguments[isolationArgumentIndex])
      }

      if let sourceLocationArgumentIndex {
        checkArguments.append(macroArguments[sourceLocationArgumentIndex])
      } else {
        checkArguments.append(Argument(label: _sourceLocationLabel, expression: createSourceLocationExpr(of: macro, context: context)))
      }
    }

    // Construct and return the call to __check().
    var call: ExprSyntax = "Testing.\(expandedFunctionName)(\(LabeledExprListSyntax(checkArguments)))"
    call = if isThrowing {
      "\(call).__required()"
    } else {
      "\(call).__expected()"
    }
    if effectKeywordsToApply.contains(.await) {
      call = "await \(call)"
    }
    if !isThrowing && effectKeywordsToApply.contains(.try) {
      call = "try \(call)"
    }
    return call
  }

  /// Get the complete argument list for a given macro, including any trailing
  /// closures.
  ///
  /// - Parameters:
  ///   - macro: The macro being inspected.
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: A copy of the argument list of `macro` with trailing closures
  ///   included.
  static func argumentList(
    of macro: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) -> [Argument] {
    var result = [Argument]()

    // NOTE: An #expect() or #require() invocation can have a condition argument
    // OR a trailing closure, but not both. If it has both, then that makes it
    // ambiguous to parse an invocation with a comment argument such as:
    //
    // #expect(x) { ... }
    //
    // Since we do not have enough context during macro expansion to know if the
    // "x" argument is the condition or a comment. Additional labelled arguments
    // are allowed.

    // Include the original arguments first.
    result += macro.arguments.lazy.map(Argument.init)

    if let trailingClosure = macro.trailingClosure {
      // Since a trailing closure does not (syntactically) include a label, we
      // assume that the argument has the mandatory label described above.
      result.append(Argument(label: _trailingClosureLabel, expression: trailingClosure))
    }

    // Include any additional trailing closures. These trailing closures will
    // always have labels.

    result += macro.additionalTrailingClosures.lazy.map(Argument.init)

    return result
  }
}

// MARK: -

/// A type describing the expansion of the `#expect()` macro.
public struct ExpectMacro: ConditionMacro {
  public static var isThrowing: Bool {
    false
  }
}

// MARK: -

/// A type describing the expansion of the `#require()` macro.
public struct RequireMacro: ConditionMacro {
  public static var isThrowing: Bool {
    true
  }
}

/// A type describing the expansion of the `#require()` macro when it produces
/// an optional value.
public struct UnwrapMacro: ConditionMacro {
  public static var isThrowing: Bool {
    true
  }

  public static var returnType: TypeSyntax? {
    TypeSyntax(
      MemberTypeSyntax(
        baseType: IdentifierTypeSyntax(name: .identifier("Swift")),
        name: .identifier("Optional")
      )
    )
  }
}

// MARK: - Refined condition macros

/// A protocol that can be used to create a condition macro that refines the
/// behavior of another previously-defined condition macro.
public protocol RefinedConditionMacro: ConditionMacro {
  associatedtype Base: ConditionMacro
}

extension RefinedConditionMacro {
  public static var isThrowing: Bool {
    Base.isThrowing
  }

  public static var returnType: TypeSyntax? {
    Base.returnType
  }
}

// MARK: - Diagnostics-emitting condition macros

/// A type describing the expansion of the `#require()` macro when it is
/// ambiguous whether it refers to a boolean check or optional unwrapping.
///
/// This type is otherwise exactly equivalent to ``RequireMacro``.
public struct AmbiguousRequireMacro: RefinedConditionMacro {
  public typealias Base = UnwrapMacro

  public static func expansion(
    of macro: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    if let argument = macro.arguments.first {
      _checkAmbiguousArgument(argument.expression, in: context)
    }

    // Perform the normal macro expansion for #require().
    return try Base.expansion(of: macro, in: context)
  }

  /// Check for an ambiguous argument to the `#require()` macro and emit the
  /// appropriate diagnostics.
  ///
  /// - Parameters:
  ///   - argument: The ambiguous argument.
  ///   - context: The macro context in which the expression is being parsed.
  private static func _checkAmbiguousArgument(_ argument: ExprSyntax, in context: some MacroExpansionContext) {
    // If the argument is wrapped in parentheses, strip them before continuing.
    if let argumentWithoutParentheses = removeParentheses(from: argument) {
      return _checkAmbiguousArgument(argumentWithoutParentheses, in: context)
    }

    // If the argument is explicitly an as? cast already, do not diagnose.
    if argument.is(AsExprSyntax.self) {
      return
    }

    // If we reach this point, then the argument appears to be an ambiguous
    // expression and we aren't sure if the developer intended to unwrap a Bool?
    // or check the value of the wrapped Bool.
    context.diagnose(.optionalBoolExprIsAmbiguous(argument))
  }
}

/// A type describing the expansion of the `#require()` macro when it is passed
/// a non-optional, non-`Bool` value.
///
/// This type is otherwise exactly equivalent to ``RequireMacro``.
public struct NonOptionalRequireMacro: RefinedConditionMacro {
  public typealias Base = UnwrapMacro

  public static func expansion(
    of macro: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    if let argument = macro.arguments.first {
#if !SWT_FIXED_137943258
      // Silence this warning if we see a token (`?`, `nil`, or "Optional") that
      // might indicate the test author expects the expression is optional.
      let tokenKindsIndicatingOptionality: [TokenKind] = [
        .infixQuestionMark,
        .postfixQuestionMark,
        .keyword(.nil),
        .identifier("Optional")
      ]
      let looksOptional = argument.tokens(viewMode: .sourceAccurate).lazy
        .map(\.tokenKind)
        .contains(where: tokenKindsIndicatingOptionality.contains)
      if !looksOptional {
        context.diagnose(.nonOptionalRequireIsRedundant(argument.expression, in: macro))
      }
#else
      context.diagnose(.nonOptionalRequireIsRedundant(argument.expression, in: macro))
#endif
    }

    // Perform the normal macro expansion for #require().
    return try Base.expansion(of: macro, in: context)
  }
}

/// A type describing the expansion of the `#require(throws:)` macro.
///
/// This macro makes a best effort to check if the type argument is `Never.self`
/// (as we only have the syntax tree here) and diagnoses it as redundant if so.
/// See also ``RequireThrowsNeverMacro`` which is used when full type checking
/// is contextually available.
///
/// This type is otherwise exactly equivalent to ``RequireMacro``.
public struct RequireThrowsMacro: RefinedConditionMacro {
  public typealias Base = RequireMacro

  public static func expansion(
    of macro: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    if let argument = macro.arguments.first {
      let argumentTokens: [String] = argument.expression.tokens(viewMode: .fixedUp).lazy
        .filter { $0.tokenKind != .period }
        .map(\.textWithoutBackticks)
      if argumentTokens == ["Swift", "Never", "self"] || argumentTokens == ["Never", "self"] {
        context.diagnose(.requireThrowsNeverIsRedundant(argument.expression, in: macro))
      }
    }

    // Perform the normal macro expansion for #require().
    return try Base.expansion(of: macro, in: context)
  }
}

/// A type describing the expansion of the `#require(throws:)` macro when it is
/// passed `Never.self`, which is redundant.
///
/// This type is otherwise exactly equivalent to ``RequireMacro``.
public struct RequireThrowsNeverMacro: RefinedConditionMacro {
  public typealias Base = RequireMacro

  public static func expansion(
    of macro: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    if let argument = macro.arguments.first {
      context.diagnose(.requireThrowsNeverIsRedundant(argument.expression, in: macro))
    }

    // Perform the normal macro expansion for #require().
    return try Base.expansion(of: macro, in: context)
  }
}

// MARK: - Exit test condition macros

public protocol ExitTestConditionMacro: RefinedConditionMacro {}

extension ExitTestConditionMacro {
  public static func expansion(
    of macro: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    // Perform the normal macro expansion for the macro with the standard set
    // of arguments. This gives us any relevant diagnostics for the body of the
    // exit test. We then discard the result (because we haven't performed any
    // additional transformations) and then re-run the macro with the
    // substituted trailing closure argument.
    _ = try Base.expansion(of: macro, in: context)

    var arguments = argumentList(of: macro, in: context)
    let requirementIndex = arguments.firstIndex { $0.label?.tokenKind == .identifier("exitsWith") }
    guard let requirementIndex else {
      fatalError("Could not find the requirement for this exit test. Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    }
    let observationListIndex = arguments.firstIndex { $0.label?.tokenKind == .identifier("observing") }
    if observationListIndex == nil {
      arguments.insert(
        Argument(label: "observing", expression: ArrayExprSyntax(expressions: [])),
        at: arguments.index(after: requirementIndex)
      )
    }
    let trailingClosureIndex = arguments.firstIndex { $0.label?.tokenKind == _trailingClosureLabel.tokenKind }
    guard let trailingClosureIndex else {
      fatalError("Could not find the body argument to this exit test. Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    }

    // Extract the body argument and, if it's a closure with a capture list,
    // emit an appropriate diagnostic.
    var bodyArgumentExpr = arguments[trailingClosureIndex].expression
    bodyArgumentExpr = removeParentheses(from: bodyArgumentExpr) ?? bodyArgumentExpr
    if let closureExpr = bodyArgumentExpr.as(ClosureExprSyntax.self),
       let captureClause = closureExpr.signature?.capture,
       !captureClause.items.isEmpty {
      context.diagnose(.captureClauseUnsupported(captureClause, in: closureExpr, inExitTest: macro))
    }

    // Generate a unique identifier for this exit test.
    let idExpr = _makeExitTestIDExpr(for: macro, in: context)

    var decls = [DeclSyntax]()

    // Implement the body of the exit test outside the enum we're declaring so
    // that `Self` resolves to the type containing the exit test, not the enum.
    let bodyThunkName = context.makeUniqueName("")
    decls.append(
      """
      @Sendable func \(bodyThunkName)() async throws -> Swift.Void {
        return \(applyEffectfulKeywords([.try, .await], to: bodyArgumentExpr))()
      }
      """
    )

    // Create a local type that can be discovered at runtime and which contains
    // the exit test body.
    let enumName = context.makeUniqueName("")
    do {
      // Create the test content record.
      let testContentRecordDecl = makeTestContentRecordDecl(
        named: .identifier("testContentRecord"),
        in: TypeSyntax(IdentifierTypeSyntax(name: enumName)),
        ofKind: .exitTest,
        accessingWith: .identifier("accessor")
      )

      // Create another local type for legacy test discovery.
      var recordDecl: DeclSyntax?
#if !SWT_NO_LEGACY_TEST_DISCOVERY
      let legacyEnumName = context.makeUniqueName("__🟡$")
      recordDecl = """
      enum \(legacyEnumName): Testing.__TestContentRecordContainer {
        nonisolated static var __testContentRecord: Testing.__TestContentRecord {
          \(enumName).testContentRecord
        }
      }
      """
#endif

      decls.append(
        """
        @available(*, deprecated, message: "This type is an implementation detail of the testing library. Do not use it directly.")
        enum \(enumName) {
          private nonisolated static let accessor: Testing.__TestContentRecordAccessor = { outValue, type, hint, _ in
            Testing.ExitTest.__store(
              \(idExpr),
              \(bodyThunkName),
              into: outValue,
              asTypeAt: type,
              withHintAt: hint
            )
          }

          \(testContentRecordDecl)

          \(recordDecl)
        }
        """
      )
    }

    arguments[trailingClosureIndex].expression = ExprSyntax(
      ClosureExprSyntax {
        for decl in decls {
          CodeBlockItemSyntax(
            leadingTrivia: .newline,
            item: .decl(decl),
            trailingTrivia: .newline
          )
        }
      }
    )

    // Insert the exit test's ID as the first argument. Note that this will
    // invalidate all indices into `arguments`!
    arguments.insert(
      Argument(label: "identifiedBy", expression: idExpr),
      at: arguments.startIndex
    )

    // Replace the exit test body (as an argument to the macro) with a stub
    // closure that hosts the type we created above.
    var macro = macro
    macro.arguments = LabeledExprListSyntax(arguments)
    macro.trailingClosure = nil
    macro.additionalTrailingClosures = MultipleTrailingClosureElementListSyntax()

    return try Base.expansion(of: macro, primaryExpression: bodyArgumentExpr, in: context)
  }

  /// Make an expression representing an exit test ID that can be passed to the
  /// `ExitTest.__store()` function at runtime.
  ///
  /// - Parameters:
  ///   - macro: The exit test macro being inspected.
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: An expression representing the exit test's unique ID.
  private static func _makeExitTestIDExpr(
    for macro: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) -> ExprSyntax {
    withUnsafeTemporaryAllocation(of: UInt64.self, capacity: 4) { exitTestID in
      if let sourceLocation = context.location(of: macro, at: .afterLeadingTrivia, filePathMode: .fileID),
         let fileID = sourceLocation.file.as(StringLiteralExprSyntax.self)?.representedLiteralValue,
         let line = sourceLocation.line.as(IntegerLiteralExprSyntax.self)?.representedLiteralValue,
         let column = sourceLocation.column.as(IntegerLiteralExprSyntax.self)?.representedLiteralValue {
        // Hash the entire source location and store the entire hash in the
        // resulting ID.
        let stringValue = "\(fileID):\(line):\(column)"
        exitTestID.withMemoryRebound(to: UInt8.self) { exitTestID in
          _ = exitTestID.initialize(from: SHA256.hash(stringValue.utf8))
        }
      } else {
        // This branch is dead code in production, but is used when we expand a
        // macro in our own unit tests because the macro expansion context does
        // not have real source location information.
        for i in 0 ..< exitTestID.count {
          exitTestID[i] = .random(in: 0 ... .max)
        }
      }

      // Return a tuple of integer literals (which is what the runtime __store()
      // function is expecting.)
      let tupleExpr = TupleExprSyntax {
        for uint64 in exitTestID {
          LabeledExprSyntax(expression: IntegerLiteralExprSyntax(uint64, radix: .hex))
        }
      }
      return ExprSyntax(tupleExpr)
    }
  }
}

/// A type describing the expansion of the `#expect(exitsWith:)` macro.
///
/// This type checks for nested invocations of `#expect()` and `#require()` and
/// diagnoses them as unsupported. It is otherwise exactly equivalent to
/// ``ExpectMacro``.
public struct ExitTestExpectMacro: ExitTestConditionMacro {
  public typealias Base = ExpectMacro
}

/// A type describing the expansion of the `#require(exitsWith:)` macro.
///
/// This type checks for nested invocations of `#expect()` and `#require()` and
/// diagnoses them as unsupported. It is otherwise exactly equivalent to
/// ``RequireMacro``.
public struct ExitTestRequireMacro: ExitTestConditionMacro {
  public typealias Base = RequireMacro
}
