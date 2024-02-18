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
  /// The complete name of this type, with the names of all referenced types
  /// fully-qualified by their module names when possible.
  public var qualifiedTypeName: String

  /// A simplified name of this type, by leaving the names of all referenced
  /// types unqualified, i.e. without module name prefixes.
  public var unqualifiedTypeName: String

  init(
    qualifiedTypeName: String,
    unqualifiedTypeName: String
  ) {
    self.qualifiedTypeName = qualifiedTypeName
    self.unqualifiedTypeName = unqualifiedTypeName
  }

  /// Initialize an instance of this type describing the specified type.
  ///
  /// - Parameters:
  ///   - type: The type which this instance should describe.
  init(_ type: Any.Type) {
    qualifiedTypeName = _typeName(type, qualified: true)
    unqualifiedTypeName = _typeName(type, qualified: false)
  }

  /// Initialize an instance of this type describing the type of the specified
  /// value.
  ///
  /// - Parameters:
  ///   - value: The value whose type this instance should describe.
  init(describingTypeOf value: some Any) {
    self.init(type(of: value as Any))
  }
}

// MARK: - CustomStringConvertible, CustomDebugStringConvertible

extension TypeInfo: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    unqualifiedTypeName
  }

  public var debugDescription: String {
    qualifiedTypeName
  }
}

// MARK: - Equatable, Hashable

extension TypeInfo: Hashable {}

// MARK: - Codable

extension TypeInfo: Codable {}
