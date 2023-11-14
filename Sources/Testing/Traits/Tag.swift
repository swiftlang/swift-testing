//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing a tag that can be applied to a test.
///
/// To apply tags to a test, use one of the following:
///
/// - ``Trait/tags(_:)-yg0i``
/// - ``Trait/tags(_:)-272p``
public struct Tag: RawRepresentable, Sendable {
  public var rawValue: String

  /// The source code of the expression that produced this tag, if available at
  /// compile time.
  var sourceCode: SourceCode?

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

// MARK: - ExpressibleByStringLiteral

extension Tag: ExpressibleByStringLiteral, CustomStringConvertible {
  public init(stringLiteral: String) {
    self.init(rawValue: stringLiteral)
  }

  public var description: String {
    rawValue
  }
}

// MARK: - Equatable, Hashable, Comparable

extension Tag: Equatable, Hashable, Comparable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue == rhs.rawValue
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue)
  }

  public static func <(lhs: Tag, rhs: Tag) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

// MARK: - Codable, CodingKeyRepresentable

extension Tag: Codable, CodingKeyRepresentable {
  public func encode(to encoder: any Encoder) throws {
    try rawValue.encode(to: encoder)
  }

  public init(from decoder: any Decoder) throws {
    try self.init(rawValue: String(from: decoder))
  }
}

// MARK: -

extension Test {
  /// The complete, unique set of tags associated with this test.
  ///
  /// Tags are associated with tests using one of these traits:
  ///
  /// - ``Trait/tags(_:)-yg0i``
  /// - ``Trait/tags(_:)-272p``
  public var tags: Set<Tag> {
    traits.lazy
      .compactMap { $0 as? Tag.List }
      .map(\.tags)
      .reduce(into: []) { $0.formUnion($1) }
  }
}
