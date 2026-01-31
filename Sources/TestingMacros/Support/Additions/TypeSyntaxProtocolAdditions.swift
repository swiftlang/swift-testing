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

/// An array of syntax node kinds that always represent generic types.
private let _knownGenericTypeKinds: [SyntaxKind] = [
  .arrayType, .dictionaryType, .optionalType,
  .implicitlyUnwrappedOptionalType, .inlineArrayType
]

extension TypeSyntaxProtocol {
  /// Whether or not this type is an optional type (`T?`, `Optional<T>`, etc.)
  var isOptional: Bool {
    if `is`(OptionalTypeSyntax.self) {
      return true
    } else if `is`(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
      return true
    }
    return isNamed("Optional", inModuleNamed: "Swift")
  }

  /// Whether or not this type is equivalent to `Void`.
  var isVoid: Bool {
    if let tuple = `as`(TupleTypeSyntax.self) {
      return tuple.elements.isEmpty
    }
    return isNamed("Void", inModuleNamed: "Swift")
  }

  /// Whether or not this type is `some T` or a type derived from such a type.
  var isSome: Bool {
    tokens(viewMode: .fixedUp).lazy
      .map(\.tokenKind)
      .contains(.keyword(.some))
  }

  /// Whether or not this type is `any T` or a type derived from such a type.
  var isAny: Bool {
    tokens(viewMode: .fixedUp).lazy
      .map(\.tokenKind)
      .contains(.keyword(.any))
  }

  /// Whether or not this type is explicitly a generic type.
  var isExplicitlyGeneric: Bool {
    // Fast(er) path: check if this type's syntax node kind is one that always
    // represents generic types.
    if _knownGenericTypeKinds.contains(kind) {
      return true
    }

    // Check if this type has a generic argument clause.
    if `as`(IdentifierTypeSyntax.self)?.genericArgumentClause != nil {
      return true
    }

    // Check if the `some` or `any` keyword is present somewhere in this type.
    let containsSomeOrAny = tokens(viewMode: .fixedUp).lazy
      .map(\.tokenKind)
      .contains { $0 == .keyword(.some) || $0 == .keyword(.any) }
    if containsSomeOrAny {
      return true
    }

    // Check the base type of this type (if any).
    if let baseType = `as`(MemberTypeSyntax.self)?.baseType {
      return baseType.isExplicitlyGeneric
    }

    return false
  }

  /// Check whether or not this type is named with the specified name and
  /// module.
  ///
  /// The type name is checked both without and with the specified module name
  /// as a prefix to allow for either syntax. When comparing the type name,
  /// generic type parameters are ignored.
  ///
  /// - Parameters:
  ///   - name: The `"."`-separated type name to compare against.
  ///   - moduleName: The module the specified type is declared in.
  ///
  /// - Returns: Whether or not this type has the given name.
  func isNamed(_ name: String, inModuleNamed moduleName: String) -> Bool {
    // Form a string of the fixed-up tokens representing the type name,
    // omitting any generic type parameters.
    let nameWithoutGenericParameters = tokens(viewMode: .fixedUp)
      .prefix { $0.tokenKind != .leftAngle }
      .filter { $0.tokenKind != .period }
      .filter { $0.tokenKind != .leftParen && $0.tokenKind != .rightParen }
      .map(\.textWithoutBackticks)
      .joined(separator: ".")

    return nameWithoutGenericParameters == name || nameWithoutGenericParameters == "\(moduleName).\(name)"
  }
}
