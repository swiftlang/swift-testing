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

extension FunctionDeclSyntax {
  /// Whether or not this function a `static` or `class` function.
  var isStaticOrClass: Bool {
    modifiers.lazy
      .map(\.name.tokenKind)
      .contains { $0 == .keyword(.class) || $0 == .keyword(.static) }
  }

  /// Whether or not this function is a `mutating` function.
  var isMutating: Bool {
    modifiers.lazy
      .map(\.name.tokenKind)
      .contains(.keyword(.mutating))
  }

  /// The name of this function including parentheses, parameter labels, and
  /// colons.
  var completeName: String {
    var result = [name.textWithoutBackticks, "(",]

    for parameter in signature.parameterClause.parameters {
      result.append(parameter.firstName.textWithoutBackticks)
      result.append(":")
    }
    result.append(")")

    return result.joined()
  }

  /// An array of tuples representing this function's parameters.
  var testFunctionParameterList: ArrayExprSyntax {
    ArrayExprSyntax {
      for parameter in signature.parameterClause.parameters {
        ArrayElementSyntax(expression: parameter.testFunctionParameter)
      }
    }
  }

  /// The selector corresponding to this function's name.
  ///
  /// - Note: This property does not support synthesizing a selector for
  ///   functions that take arguments. If the function takes any arguments, the
  ///   value of this property is `nil`.
  ///
  /// - Note: This property does not validate that a function declaration
  ///   actually has a corresponding selector or can be called from Objective-C.
  ///   That information can only be determined at runtime.
  var xcTestCompatibleSelector: ObjCSelectorPieceListSyntax? {
    // First, look for an @objc attribute with an explicit selector, and use
    // that if found.
    let objcAttribute = attributes.lazy
      .compactMap {
        if case let .attribute(attribute) = $0 {
          return attribute
        }
        return nil
      }.first { $0.attributeNameText == "objc" }
    if let objcAttribute, case let .objCName(objCName) = objcAttribute.arguments {
      if true == objCName.first?.name?.textWithoutBackticks.hasPrefix("test") {
        return objCName
      }
      return nil
    }

    // If the function has no arguments and its name starts with "test", it can
    // be discovered by XCTest, so derive its name (taking async/throws into
    // consideration.)
    if signature.parameterClause.parameters.isEmpty {
      var selector = name.textWithoutBackticks
      guard selector.starts(with: "test") else {
        return nil
      }

      // Apply the standard effect-based suffixes.
      var colonToken: TokenSyntax?
      if signature.effectSpecifiers?.asyncSpecifier != nil {
        selector += "WithCompletionHandler"
        colonToken = .colonToken()
      } else {
        let hasThrowsSpecifier: Bool
        hasThrowsSpecifier = signature.effectSpecifiers?.throwsClause != nil
        if hasThrowsSpecifier {
          selector += "AndReturnError"
          colonToken = .colonToken()
        }
      }
      return ObjCSelectorPieceListSyntax {
        ObjCSelectorPieceSyntax(name: .identifier(selector), colon: colonToken)
      }
    }

    return nil
  }
}

// MARK: -

extension FunctionParameterSyntax {
  /// A tuple containing this parameter's name(s) and type.
  ///
  /// This is meant to be included in an array of parameters and passed along
  /// with other test function details.
  ///
  /// ## See Also
  ///
  /// - ``FunctionDeclSyntax/testFunctionParameterList``
  fileprivate var testFunctionParameter: TupleExprSyntax {
    TupleExprSyntax {
      LabeledExprSyntax(label: "firstName", expression: StringLiteralExprSyntax(content: firstName.textWithoutBackticks))

      if let secondName {
        LabeledExprSyntax(label: "secondName", expression: StringLiteralExprSyntax(content: secondName.textWithoutBackticks))
      } else {
        LabeledExprSyntax(label: "secondName", expression: NilLiteralExprSyntax())
      }

      LabeledExprSyntax(label: "type", expression: typeMetatypeExpression)
    }
  }

  /// An expression which refers to the metatype of this parameter's type.
  ///
  /// For example, for the parameter `y` of `func x(y: Int)`, the value of this
  /// property is an expression equivalent to `Int.self`.
  private var typeMetatypeExpression: some ExprSyntaxProtocol {
    // Discard any specifiers such as `inout` or `borrowing`, since we're only
    // trying to obtain the base type to reference it in an expression.
    let baseType = type.as(AttributedTypeSyntax.self)?.baseType ?? type

    // Construct a member access expression, referencing the base type above.
    let baseTypeDeclReferenceExpr = DeclReferenceExprSyntax(baseName: .identifier(baseType.trimmedDescription))

    // Enclose the base type declaration reference in a 1-element tuple, e.g.
    // `(<baseType>)`. It will be used in a member access expression below, and
    // some types (such as function types) require this.
    let metatypeMemberAccessBase = TupleExprSyntax {
      LabeledExprListSyntax {
        LabeledExprSyntax(expression: baseTypeDeclReferenceExpr)
      }
    }

    return MemberAccessExprSyntax(base: metatypeMemberAccessBase, name: .identifier("self"))
  }
}
