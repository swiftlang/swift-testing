//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A description of the type of a value encountered during testing or a
/// parameter of a test function.
@_spi(ForToolsIntegrationOnly)
public struct TypeInfo: Sendable {
  /// An enumeration defining backing storage for an instance of ``TypeInfo``.
  private enum _Kind: Sendable {
    /// The type info represents a concrete metatype.
    ///
    /// - Parameters:
    ///   - type: The concrete metatype.
    case type(_ type: Any.Type)

    /// The type info represents a metatype, but a reference to that metatype is
    /// not available at runtime.
    ///
    /// - Parameters:
    ///   - fullyQualified: The fully-qualified name of the type.
    ///   - unqualified: The unqualified name of the type.
    case nameOnly(fullyQualified: String, unqualified: String)
  }

  /// The kind of type info.
  private var _kind: _Kind

  /// The complete name of this type, with the names of all referenced types
  /// fully-qualified by their module names when possible.
  ///
  /// The value of this property is equal to ``fullyQualifiedName``, but is
  /// split into components. For instance, given the following declaration in
  /// the `Example` module:
  ///
  /// ```swift
  /// struct A {
  ///   struct B {}
  /// }
  /// ```
  ///
  /// The value of this property for the type `A.B` would be
  /// `["Example", "A", "B"]`.
  public var fullyQualifiedNameComponents: [String] {
    switch _kind {
    case let .type(type):
      nameComponents(of: type)
    case let .nameOnly(fqn, _):
      fqn.split(separator: ".").map(String.init)
    }
  }

  /// The complete name of this type, with the names of all referenced types
  /// fully-qualified by their module names when possible.
  ///
  /// The value of this property is equal to ``fullyQualifiedNameComponents``,
  /// but is represented as a single string. For instance, given the following
  /// declaration in the `Example` module:
  ///
  /// ```swift
  /// struct A {
  ///   struct B {}
  /// }
  /// ```
  ///
  /// The value of this property for the type `A.B` would be `"Example.A.B"`.
  public var fullyQualifiedName: String {
    switch _kind {
    case let .type(type):
      Testing.fullyQualifiedName(of: type)
    case let .nameOnly(fqn, _):
      fqn
    }
  }

  /// A simplified name of this type, by leaving the names of all referenced
  /// types unqualified, i.e. without module name prefixes.
  ///
  /// The value of this property is equal to the name of the type in isolation.
  /// For instance, given the following declaration in the `Example` module:
  ///
  /// ```swift
  /// struct A {
  ///   struct B {}
  /// }
  /// ```
  ///
  /// The value of this property for the type `A.B` would simply be `"B"`.
  public var unqualifiedName: String {
    switch _kind {
    case let .type(type):
      String(describing: type)
    case let .nameOnly(_, unqualifiedName):
      unqualifiedName
    }
  }

  /// The described type, if available.
  ///
  /// If this instance was created from a type name, or if it was previously
  /// encoded and decoded, the value of this property is `nil`.
  public var type: Any.Type? {
    if case let .type(type) = _kind {
      return type
    }
    return nil
  }

  init(fullyQualifiedName: String, unqualifiedName: String) {
    _kind = .nameOnly(fullyQualified: fullyQualifiedName, unqualified: unqualifiedName)
  }

  /// Initialize an instance of this type describing the specified type.
  ///
  /// - Parameters:
  ///   - type: The type which this instance should describe.
  init(describing type: Any.Type) {
    _kind = .type(type)
  }

  /// Initialize an instance of this type describing the type of the specified
  /// value.
  ///
  /// - Parameters:
  ///   - value: The value whose type this instance should describe.
  init(describingTypeOf value: Any) {
    self.init(describing: Swift.type(of: value))
  }
}

// MARK: - CustomStringConvertible, CustomDebugStringConvertible

extension TypeInfo: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    unqualifiedName
  }

  public var debugDescription: String {
    fullyQualifiedName
  }
}

// MARK: - Equatable, Hashable

extension TypeInfo: Hashable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    switch (lhs._kind, rhs._kind) {
    case let (.type(lhs), .type(rhs)):
      return lhs == rhs
    default:
      return lhs.fullyQualifiedNameComponents == rhs.fullyQualifiedNameComponents
    }
  }

  public func hash(into hasher: inout Hasher) {
    switch _kind {
    case let .type(type):
      hasher.combine(ObjectIdentifier(type))
    case let .nameOnly(fqnComponents, _):
      hasher.combine(fqnComponents)
    }
  }
}

// MARK: - Codable

extension TypeInfo: Codable {
  /// A simplified version of ``TypeInfo`` suitable for encoding and decoding.
  fileprivate struct EncodedForm {
    /// The complete name of this type, with the names of all referenced types
    /// fully-qualified by their module names when possible.
    public var fullyQualifiedName: String

    /// A simplified name of this type, by leaving the names of all referenced
    /// types unqualified, i.e. without module name prefixes.
    public var unqualifiedName: String
  }

  public func encode(to encoder: any Encoder) throws {
    let encodedForm = EncodedForm(fullyQualifiedName: fullyQualifiedName, unqualifiedName: unqualifiedName)
    try encodedForm.encode(to: encoder)
  }

  public init(from decoder: any Decoder) throws {
    let encodedForm = try EncodedForm(from: decoder)
    self.init(fullyQualifiedName: encodedForm.fullyQualifiedName, unqualifiedName: encodedForm.unqualifiedName)
  }
}

extension TypeInfo.EncodedForm: Codable {}
