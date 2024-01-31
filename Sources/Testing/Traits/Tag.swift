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
/// To apply tags to a test, use ``Trait/tags(_:)``.
public struct Tag: RawRepresentable, Sendable {
  public var rawValue: String

  /// The expression that produced this tag, if available at compile time.
  var expression: Expression?

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

extension Tag: Codable, CodingKeyRepresentable {}

// MARK: -

extension Test {
  /// The complete, unique set of tags associated with this test.
  ///
  /// Tags are associated with tests using ``Trait/tags(_:)``.
  public var tags: Set<Tag> {
    traits.lazy
      .compactMap { $0 as? Tag.List }
      .map(\.tags)
      .reduce(into: []) { $0.formUnion($1) }
  }
}
