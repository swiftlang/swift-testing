//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing a bug report tracked by a test.
///
/// To add this trait to a test, use one of the following functions:
///
/// - ``Trait/bug(_:_:)-2u8j9``
/// - ``Trait/bug(_:_:)-7mo2w``
public struct Bug {
  /// The identifier of this bug in the associated bug-tracking system.
  ///
  /// For more information on how the testing library interprets bug
  /// identifiers, see <doc:BugIdentifiers>.
  public var identifier: String

  /// An optional, user-specified comment describing this trait.
  public var comment: Comment?
}

// MARK: - Equatable, Hashable, Comparable

extension Bug: Equatable, Hashable, Comparable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.identifier == rhs.identifier
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }

  public static func <(lhs: Self, rhs: Self) -> Bool {
    lhs.identifier < rhs.identifier
  }
}

// MARK: - Codable

extension Bug: Codable {
  /// A temporary explicit implementation of this type's coding keys enumeration
  /// to support the refactored form of `Bug` from [#412](https://github.com/apple/swift-testing/pull/412).
  private enum _CodingKeys: String, CodingKey {
    // Existing properties.
    case identifier = "identifier"
    case comment = "comment"

    // Proposed new properties.
    case id = "id"
    case url = "url"
    case title = "title"
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: _CodingKeys.self)

    try container.encode(identifier, forKey: .identifier)
    try container.encodeIfPresent(comment, forKey: .comment)

    // Temporary compatibility shims to support the refactored form of Bug from
    // https://github.com/apple/swift-testing/pull/412 .
    if identifier.contains(":") {
      try container.encode(identifier, forKey: .url)
    } else {
      try container.encode(identifier, forKey: .id)
    }
    try container.encodeIfPresent(comment, forKey: .title)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: _CodingKeys.self)
    identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
      // Temporary compatibility shims to support the refactored form of Bug
      // from https://github.com/apple/swift-testing/pull/412 .
      ?? container.decodeIfPresent(String.self, forKey: .id)
      ?? container.decode(String.self, forKey: .url)
    comment = try container.decodeIfPresent(Comment.self, forKey: .comment)
      ?? container.decodeIfPresent(Comment.self, forKey: .title)
  }
}

// MARK: - Trait, TestTrait, SuiteTrait

extension Bug: TestTrait, SuiteTrait {
  public var comments: [Comment] {
    Array(comment)
  }
}

extension Trait where Self == Bug {
  /// Construct a bug to track with a test.
  ///
  /// - Parameters:
  ///   - identifier: The identifier of this bug in the associated bug-tracking
  ///     system. For more information on how this value is interpreted, see the
  ///     documentation for ``Bug``.
  ///   - comment: An optional, user-specified comment describing this trait.
  ///
  /// - Returns: An instance of ``Bug`` representing the specified bug.
  public static func bug(_ identifier: String, _ comment: Comment? = nil) -> Self {
    Self(identifier: identifier, comment: comment)
  }

  /// Construct a bug to track with a test.
  ///
  /// - Parameters:
  ///   - identifier: The identifier of this bug in the associated bug-tracking
  ///     system. For more information on how this value is interpreted, see the
  ///     documentation for ``Bug``.
  ///   - comment: An optional, user-specified comment describing this trait.
  ///
  /// - Returns: An instance of ``Bug`` representing the specified bug.
  public static func bug(_ identifier: some Numeric, _ comment: Comment? = nil) -> Self {
    Self(identifier: String(describing: identifier), comment: comment)
  }
}

// MARK: -

extension Test {
  /// The set of bugs associated with this test.
  ///
  /// For information on how to associate a bug with a test, see the
  /// documentation for ``Bug``.
  public var associatedBugs: [Bug] {
    traits.compactMap { $0 as? Bug }
  }
}
