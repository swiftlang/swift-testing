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

/// A type describing the expansion of the `@Test` attribute macro.
///
/// This type is used to implement the `@Test` attribute macro. Do not use it
/// directly.
public struct TestDeclarationMacro: PeerMacro, Sendable {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard _diagnoseIssues(with: declaration, testAttribute: node, in: context) else {
      return []
    }

    let functionDecl = declaration.cast(FunctionDeclSyntax.self)
    let typeName = context.typeOfLexicalContext

    return _createTestContainerDecls(for: functionDecl, on: typeName, testAttribute: node, in: context)
  }

  /// Diagnose issues with a `@Test` declaration.
  ///
  /// - Parameters:
  ///   - declaration: The function declaration to diagnose.
  ///   - testAttribute: The `@Test` attribute applied to `declaration`.
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: Whether or not macro expansion should continue (i.e. stopping
  ///   if a fatal error was diagnosed.)
  private static func _diagnoseIssues(
    with declaration: some DeclSyntaxProtocol,
    testAttribute: AttributeSyntax,
    in context: some MacroExpansionContext
  ) -> Bool {
    var diagnostics = [DiagnosticMessage]()
    defer {
      context.diagnose(diagnostics)
    }

    // The @Test attribute is only supported on function declarations.
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      diagnostics.append(.attributeNotSupported(testAttribute, on: declaration))
      return false
    }

    // Check if the lexical context is appropriate for a suite or test.
    diagnostics += diagnoseIssuesWithLexicalContext(context.lexicalContext, containing: declaration, attribute: testAttribute)

    // Only one @Test attribute is supported.
    let suiteAttributes = function.attributes(named: "Test")
    if suiteAttributes.count > 1 {
      diagnostics.append(.multipleAttributesNotSupported(suiteAttributes, on: declaration))
    }

    let parameterList = function.signature.parameterClause.parameters

    // We don't support inout, isolated, or _const parameters on test functions.
    for parameter in parameterList {
      let invalidSpecifierKeywords: [TokenKind] = [.keyword(.inout), .keyword(.isolated), .keyword(._const),]
      if let parameterType = parameter.type.as(AttributedTypeSyntax.self) {
        for specifier in parameterType.specifiers {
          guard case let .simpleTypeSpecifier(specifier) = specifier else {
            continue
          }
          if invalidSpecifierKeywords.contains(specifier.specifier.tokenKind) {
            diagnostics.append(.specifierNotSupported(specifier.specifier, on: parameter, whenUsing: testAttribute))
          }
        }
      }
    }

    // Disallow functions with return types. We could conceivably support
    // arbitrary return types in the future, but we do not have a use case for
    // them at this time.
    if let returnType = function.signature.returnClause?.type, !returnType.isVoid {
      diagnostics.append(.returnTypeNotSupported(returnType, on: function, whenUsing: testAttribute))
    }

    // Disallow generic test functions. Although we can conceivably support
    // generic functions when they are parameterized and the types line up, we
    // have not identified a need for them.
    if let genericClause = function.genericParameterClause {
      diagnostics.append(.genericDeclarationNotSupported(function, whenUsing: testAttribute, becauseOf: genericClause, on: function))
    } else if let whereClause = function.genericWhereClause {
      diagnostics.append(.genericDeclarationNotSupported(function, whenUsing: testAttribute, becauseOf: whereClause, on: function))
    } else {
      for parameter in parameterList {
        if parameter.type.isSome {
          diagnostics.append(.genericDeclarationNotSupported(function, whenUsing: testAttribute, becauseOf: parameter, on: function))
        }
      }
    }

    return !diagnostics.lazy.map(\.severity).contains(.error)
  }

  /// Create a function call parameter list used to call a function from its
  /// corresponding thunk function.
  ///
  /// - Parameters:
  ///   - parametersWithLabels: A sequence of tuples containing parameters to
  ///     the original function and their corresponding identifiers as used by
  ///     the thunk function.
  ///
  /// - Returns: A tuple expression representing the arguments passed to the
  ///   original function by the thunk function.
  private static func _createForwardedParamsExpr(
    from parametersWithLabels: some Sequence<(DeclReferenceExprSyntax, FunctionParameterSyntax)>
  ) -> TupleExprSyntax {
    let elementList = LabeledExprListSyntax {
      for (label, parameter) in parametersWithLabels {
        if parameter.firstName.tokenKind == .wildcard {
          LabeledExprSyntax(expression: label)
        } else {
          LabeledExprSyntax(label: parameter.firstName.textWithoutBackticks, expression: label)
        }
      }
    }
    return TupleExprSyntax(elements: elementList)
  }

  /// Create a function declaration parameter list used when declaring a thunk
  /// function.
  ///
  /// - Parameters:
  ///   - parametersWithLabels: A sequence of tuples containing parameters to
  ///     the original function and their corresponding identifiers as used by
  ///     the thunk function.
  ///
  /// - Returns: A parameter clause syntax node representing the arguments to
  ///   the thunk function.
  private static func _createThunkParamsExpr(
    from parametersWithLabels: some Sequence<(DeclReferenceExprSyntax, FunctionParameterSyntax)>
  ) -> FunctionParameterClauseSyntax {
    let parameterList = FunctionParameterListSyntax {
      for (label, parameter) in parametersWithLabels {
        FunctionParameterSyntax(
          firstName: parameter.firstName.trimmed
            .with(\.trailingTrivia, .space), // BUG: swift-syntax#1934
          secondName: label.baseName,
          type: parameter.type.trimmed
        )
      }
    }
    return FunctionParameterClauseSyntax(parameters: parameterList)
  }

  /// Create a closure capture list used to capture the arguments to a function
  /// when calling it from its corresponding thunk function.
  ///
  /// - Parameters:
  ///   - parametersWithLabels: A sequence of tuples containing parameters to
  ///     the original function and their corresponding identifiers as used by
  ///     the thunk function.
  ///
  /// - Returns: A closure capture list syntax node representing the arguments
  ///   to the thunk function.
  ///
  /// We need to construct a capture list when calling a synchronous test
  /// function because of the call to `__ifMainActorIsolationEnforced(_:else:)`
  /// that we insert. That function theoretically captures all arguments twice,
  /// which is not allowed for arguments marked `borrowing` or `consuming`. The
  /// capture list forces those arguments to be copied, side-stepping the issue.
  ///
  /// - Note: We do not support move-only types as arguments yet. Instances of
  ///   move-only types cannot be used with generics, so they cannot be elements
  ///   of a `Collection`.
  private static func _createCaptureListExpr(
    from parametersWithLabels: some Sequence<(DeclReferenceExprSyntax, FunctionParameterSyntax)>
  ) -> ClosureCaptureClauseSyntax {
    let specifierKeywordsNeedingCopy: [TokenKind] = [.keyword(.borrowing), .keyword(.consuming),]
    let closureCaptures = parametersWithLabels.lazy.map { label, parameter in
      var needsCopy = false
      if let parameterType = parameter.type.as(AttributedTypeSyntax.self) {
        needsCopy = parameterType.specifiers.contains { specifier in
          guard case let .simpleTypeSpecifier(specifier) = specifier else {
            return false
          }
          return specifierKeywordsNeedingCopy.contains(specifier.specifier.tokenKind)
        }
      }

      if needsCopy {
        return ClosureCaptureSyntax(
          name: label.baseName,
          equal: .equalToken(),
          expression: CopyExprSyntax(
            copyKeyword: .keyword(.copy).with(\.trailingTrivia, .space),
            expression: label
          )
        )
      } else {
        return ClosureCaptureSyntax(expression: label)
      }
    }

    return ClosureCaptureClauseSyntax {
      for closureCapture in closureCaptures {
        closureCapture
      }
    }
  }

  /// The `static` keyword, if `typeName` is not `nil`.
  ///
  /// - Parameters:
  ///   - typeName: The name of the type containing the macro being expanded.
  ///
  /// - Returns: A token representing the `static` keyword, or one representing
  ///   nothing if `typeName` is `nil`.
  private static func _staticKeyword(for typeName: TypeSyntax?) -> TokenSyntax {
    (typeName != nil) ? .keyword(.static) : .unknown("")
  }

  /// Create a thunk function with a normalized signature that calls a
  /// developer-supplied test function.
  ///
  /// - Parameters:
  ///   - functionDecl: The function declaration to write a thunk for.
  ///   - typeName: The name of the type of which `functionDecl` is a member, if
  ///     any.
  ///   - selectorExpr: The XCTest-compatible selector corresponding to
  ///     `functionDecl`, if any.
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: A syntax node that declares a function thunking `functionDecl`.
  private static func _createThunkDecl(
    calling functionDecl: FunctionDeclSyntax,
    on typeName: TypeSyntax?,
    xcTestCompatibleSelector selectorExpr: ExprSyntax?,
    in context: some MacroExpansionContext
  ) -> FunctionDeclSyntax {
    // Get the function's parameters along with the labels we'll use internally
    // to refer to them. (Not .lazy because the list is used multiple times.)
    let parametersWithLabels = functionDecl.signature.parameterClause.parameters
      .enumerated()
      .map { (.identifier("arg\($0)"), $1) }
      .map { (DeclReferenceExprSyntax(baseName: $0), $1) }

    // Get the various transformations of the parameter list needed when
    // constructing the thunk function. The capture list is only sometimes
    // needed, so it's lazy.
    let forwardedParamsExpr = _createForwardedParamsExpr(from: parametersWithLabels)
    let thunkParamsExpr = _createThunkParamsExpr(from: parametersWithLabels)
    lazy var captureListExpr = _createCaptureListExpr(from: parametersWithLabels)

    // How do we call a function if we don't know whether it's `async` or
    // `throws`? Yes, we know if the keywords are on the function, but it could
    // be actor-isolated or otherwise declared in a way that requires the use of
    // `await` without us knowing. Abstract away the need to know by invoking
    // the function along with an expression that always needs `try` and one
    // that always needs `await`, then discard the results of those expressions.
    //
    // We may also need to call init() (although only for instance methods.)
    // Since we can't see the actual init() declaration (and it may be
    // synthesized), we can't know if it's noasync, so we assume it's not.
    //
    // If the function is noasync, we will need to call it from a synchronous
    // context. Although `async` is out of the picture, we still don't know if
    // `try` is needed, so we do the same tuple dance within the closure.
    // Calling the closure requires `try`, hence why we have two `try` keywords.
    //
    // If the function is noasync *and* main-actor-isolated, we'll call through
    // MainActor.run to invoke it. We do not have a general mechanism for
    // detecting isolation to other global actors.
    lazy var isMainActorIsolated = !functionDecl.attributes(named: "MainActor", inModuleNamed: "Swift").isEmpty
    var forwardCall: (ExprSyntax) -> ExprSyntax = {
      "try await Testing.__requiringTry(Testing.__requiringAwait(\($0)))"
    }
    let forwardInit = forwardCall
    if functionDecl.noasyncAttribute != nil {
      if isMainActorIsolated {
        forwardCall = {
          "try await MainActor.run { try Testing.__requiringTry(\($0)) }"
        }
      } else {
        forwardCall = {
          "try { try Testing.__requiringTry(\($0)) }()"
        }
      }
    }

    // Generate a thunk function that invokes the actual function.
    var thunkBody: CodeBlockItemListSyntax
    if functionDecl.availability(when: .unavailable).first != nil {
      thunkBody = ""
    } else if let typeName {
      if functionDecl.isStaticOrClass {
        thunkBody = "_ = \(forwardCall("\(typeName).\(functionDecl.name.trimmed)\(forwardedParamsExpr)"))"
      } else {
        let instanceName = context.makeUniqueName(thunking: functionDecl)
        let varOrLet = functionDecl.isMutating ? "var" : "let"
        thunkBody = """
        \(raw: varOrLet) \(raw: instanceName) = \(forwardInit("\(typeName)()"))
        _ = \(forwardCall("\(raw: instanceName).\(functionDecl.name.trimmed)\(forwardedParamsExpr)"))
        """

        // If there could be an Objective-C selector associated with this test,
        // call a hook function and give XCTest a chance to take over running
        // the test.
        if let selectorExpr {
          // Provide XCTest the source location of the test function. Use the
          // start of the function's name when determining the location (instead
          // of the start of the @Test attribute as used elsewhere.) This
          // matches the indexer's heuristic when discovering XCTest functions.
          let sourceLocationExpr = createSourceLocationExpr(of: functionDecl.name, context: context)

          thunkBody = """
          if try await Testing.__invokeXCTestCaseMethod(\(selectorExpr), onInstanceOf: \(typeName).self, sourceLocation: \(sourceLocationExpr)) {
            return
          }
          \(thunkBody)
          """
        }
      }
    } else {
      thunkBody = "_ = \(forwardCall("\(functionDecl.name.trimmed)\(forwardedParamsExpr)"))"
    }

    // If this function is synchronous and is not explicitly isolated to the
    // main actor, it may still need to run main-actor-isolated depending on the
    // runtime configuration in the test process.
    if functionDecl.signature.effectSpecifiers?.asyncSpecifier == nil && !isMainActorIsolated {
      thunkBody = """
      try await Testing.__ifMainActorIsolationEnforced { \(captureListExpr) in
        \(thunkBody)
      } else: { \(captureListExpr) in
        \(thunkBody)
      }
      """
    }

    // Add availability guards if needed.
    thunkBody = createSyntaxNode(
      guardingForAvailabilityOf: functionDecl,
      beforePerforming: thunkBody,
      in: context
    )

    let thunkName = context.makeUniqueName(thunking: functionDecl)
    let thunkDecl: DeclSyntax = """
    @available(*, deprecated, message: "This function is an implementation detail of the testing library. Do not use it directly.")
    @Sendable private \(_staticKeyword(for: typeName)) func \(thunkName)\(thunkParamsExpr) async throws -> Void {
      \(thunkBody)
    }
    """

    return thunkDecl.cast(FunctionDeclSyntax.self)
  }

  /// Create a declaration for a type that conforms to the `__TestContainer`
  /// protocol and which contains a test for the given function.
  ///
  /// - Parameters:
  ///   - functionDecl: The function declaration the result should encapsulate.
  ///   - typeName: The name of the type of which `functionDecl` is a member, if
  ///     any.
  ///   - testAttribute: The `@Test` attribute applied to `declaration`.
  ///   - context: The macro context in which the expression is being parsed.
  ///
  /// - Returns: An array of declarations providing runtime information about
  ///   the test function `functionDecl`.
  private static func _createTestContainerDecls(
    for functionDecl: FunctionDeclSyntax,
    on typeName: TypeSyntax?,
    testAttribute: AttributeSyntax,
    in context: some MacroExpansionContext
  ) -> [DeclSyntax] {
    var result = [DeclSyntax]()

    // Get the name of the type containing the function for passing to the test
    // factory function later.
    let typeNameExpr: ExprSyntax = typeName.map { "\($0).self" } ?? "nil"

    if typeName != nil, let genericGuardDecl = makeGenericGuardDecl(guardingAgainst: functionDecl, in: context) {
      result.append(genericGuardDecl)
    }

    // Parse the @Test attribute.
    let attributeInfo = AttributeInfo(byParsing: testAttribute, on: functionDecl, in: context)
    if attributeInfo.hasFunctionArguments != !functionDecl.signature.parameterClause.parameters.isEmpty {
      // The attribute has arguments but the function does not (or vice versa.)
      // Note we do not consider the count of each argument list because tuple
      // destructuring means the counts might not match but the function is
      // still callable. If there's a mismatch that the compiler cannot resolve,
      // it will still emit its own error later.
      context.diagnose(.attributeArgumentCountIncorrect(testAttribute, on: functionDecl))
    }

    // Generate a selector expression compatible with XCTest.
    var selectorExpr: ExprSyntax?
    if let selector = functionDecl.xcTestCompatibleSelector {
      let selectorLiteral = String(selector.tokens(viewMode: .fixedUp).lazy.flatMap(\.textWithoutBackticks))
      selectorExpr = "Testing.__xcTestCompatibleSelector(\(literal: selectorLiteral))"
    }

    // Generate a thunk function that invokes the actual function.
    let thunkDecl = _createThunkDecl(
      calling: functionDecl,
      on: typeName,
      xcTestCompatibleSelector: selectorExpr,
      in: context
    )
    result.append(DeclSyntax(thunkDecl))

    // Create the expression that returns the Test instance for the function.
    var testsBody: CodeBlockItemListSyntax = """
    return [
      .__function(
        named: \(literal: functionDecl.completeName),
        in: \(typeNameExpr),
        xcTestCompatibleSelector: \(selectorExpr ?? "nil"),
        \(raw: attributeInfo.functionArgumentList(in: context)),
        parameters: \(raw: functionDecl.testFunctionParameterList),
        testFunction: \(thunkDecl.name)
      )
    ]
    """

    // If this function has arguments, then it can only be referenced (let alone
    // called) if the types of those arguments are available at runtime.
    if attributeInfo.hasFunctionArguments && !functionDecl.availabilityAttributes.isEmpty {
      // Create an alternative thunk that produces a Test instance with no body
      // or arguments. We can then use this thunk in place of the "real" one in
      // case the availability checks fail below.
      let unavailableTestName = context.makeUniqueName(thunking: functionDecl)

      // TODO: don't assume otherArguments is only parameterized function arguments
      var attributeInfo = attributeInfo
      attributeInfo.otherArguments = []
      result.append(
        """
        @available(*, deprecated, message: "This property is an implementation detail of the testing library. Do not use it directly.")
        private \(_staticKeyword(for: typeName)) nonisolated func \(unavailableTestName)() async -> [Testing.Test] {
          [
            .__function(
              named: \(literal: functionDecl.completeName),
              in: \(typeNameExpr),
              xcTestCompatibleSelector: \(selectorExpr ?? "nil"),
              \(raw: attributeInfo.functionArgumentList(in: context)),
              testFunction: {}
            )
          ]
        }
        """
      )

      // Add availability guards if needed. If none are needed, the extra thunk
      // is unused.
      testsBody = createSyntaxNode(
        guardingForAvailabilityOf: functionDecl,
        beforePerforming: testsBody,
        orExitingWith: "return await \(unavailableTestName)()",
        in: context
      )
    }

    // The emitted type must be public or the compiler can optimize it away
    // (since it is not actually used anywhere that the compiler can see.)
    //
    // The emitted type must be deprecated to avoid causing warnings in client
    // code since it references the test function thunk, which is itself
    // deprecated to allow test functions to validate deprecated APIs. The
    // emitted type is also annotated unavailable, since it's meant only for use
    // by the testing library at runtime. The compiler does not allow combining
    // 'unavailable' and 'deprecated' into a single availability attribute:
    // rdar://111329796
    let enumName = context.makeUniqueName(thunking: functionDecl, withPrefix: "__🟠$test_container__function__")
    result.append(
      """
      @available(*, deprecated, message: "This type is an implementation detail of the testing library. Do not use it directly.")
      enum \(enumName): Testing.__TestContainer {
        static var __tests: [Testing.Test] {
          get async {
            \(raw: testsBody)
          }
        }
      }
      """
    )

    return result
  }
}
