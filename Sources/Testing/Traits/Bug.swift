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
/// - ``Trait/bug(_:_:)``
/// - ``Trait/bug(_:id:_:)-10yf5``
/// - ``Trait/bug(_:id:_:)-3vtpl``
public struct Bug {
  /// A URL linking to more information about the bug, if available.
  ///
  /// The value of this property represents a URL conforming to
  /// [RFC 3986](https://www.ietf.org/rfc/rfc3986.txt).
  public var url: String?

  /// A unique identifier in this bug's associated bug-tracking system, if
  /// available.
  ///
  /// For more information on how the testing library interprets bug
  /// identifiers, see <doc:BugIdentifiers>.
  public var id: String?

  /// The human-readable title of the bug, if specified by the test author.
  public var title: Comment?
}

// MARK: - Equatable, Hashable

extension Bug: Equatable, Hashable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.url == rhs.url && lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(url)
    hasher.combine(id)
  }
}

// MARK: - Codable

extension Bug: Codable {}

// MARK: - Trait, TestTrait, SuiteTrait

extension Bug: TestTrait, SuiteTrait {
  public var comments: [Comment] {
    Array(title)
  }
}

extension Trait where Self == Bug {
  /// Construct a bug to track with a test.
  ///
  /// - Parameters:
  ///   - url: A URL referring to this bug in the associated bug-tracking
  ///     system.
  ///   - title: Optionally, the human-readable title of the bug.
  ///
  /// - Returns: An instance of ``Bug`` representing the specified bug.
  public static func bug(_ url: _const String, _ title: Comment? = nil) -> Self {
    Self(url: url, title: title)
  }

  /// Construct a bug to track with a test.
  ///
  /// - Parameters:
  ///   - url: A URL referring to this bug in the associated bug-tracking
  ///     system.
  ///   - id: The unique identifier of this bug in its associated bug-tracking
  ///     system.
  ///   - title: Optionally, the human-readable title of the bug.
  ///
  /// - Returns: An instance of ``Bug`` representing the specified bug.
  public static func bug(_ url: _const String? = nil, id: some Numeric, _ title: Comment? = nil) -> Self {
    Self(url: url, id: String(describing: id), title: title)
  }

  /// Construct a bug to track with a test.
  ///
  /// - Parameters:
  ///   - url: A URL referring to this bug in the associated bug-tracking
  ///     system.
  ///   - id: The unique identifier of this bug in its associated bug-tracking
  ///     system.
  ///   - title: Optionally, the human-readable title of the bug.
  ///
  /// - Returns: An instance of ``Bug`` representing the specified bug.
  public static func bug(_ url: _const String? = nil, id: _const String, _ title: Comment? = nil) -> Self {
    Self(url: url, id: id, title: title)
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
