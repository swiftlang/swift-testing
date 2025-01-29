//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that represents a comment related to a test.
///
/// Use this type to provide context or background information about a
/// test's purpose, explain how a complex test operates, or include details
/// which may be helpful when diagnosing issues recorded by a test.
///
/// To add a comment to a test or suite, add a code comment before its `@Test`
/// or `@Suite` attribute. See <doc:AddingComments> for more details.
///
/// - Note: To reference bugs related to a test, use ``Trait/bug(_:_:)``,
///   ``Trait/bug(_:id:_:)-10yf5``, or ``Trait/bug(_:id:_:)-3vtpl``.
public struct Comment: RawRepresentable, Sendable {
  /// The single comment string that this comment contains.
  ///
  /// To get the complete set of comments applied to a test, see
  /// ``Test/comments``.
  public var rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// An enumeration describing the possible kind of a comment.
  @_spi(ForToolsIntegrationOnly)
  public enum Kind: Sendable {
    /// This comment is in a single-line comment in the test's source code
    /// that starts with `//`.
    case line

    /// This comment is in a block comment in the test's source code
    /// that starts with `/*` and ends with `*/`.
    case block

    /// This comment is in a single-line [Markup](https://github.com/swiftlang/swift/blob/main/docs/DocumentationComments.md)
    /// comment in the test's source code that starts with `///`.
    case documentationLine

    /// This comment is in a block [Markup](https://github.com/swiftlang/swift/blob/main/docs/DocumentationComments.md)
    /// comment in the test's source code that starts with `/**` and ends with
    /// `*/`.
    case documentationBlock

    /// This comment comes from an explicit call to ``Trait/comment(_:)``.
    case trait

    /// This comment is initialized from a string literal.
    case stringLiteral
  }

  /// The kind of this comment, if known.
  ///
  /// For comments you create by calling ``init(rawValue:)``, the value
  /// of this property is `nil`. Otherwise, it represents the comment's kind.
  @_spi(ForToolsIntegrationOnly)
  public var kind: Kind?

  /// Initialize a comment from a string value.
  ///
  /// - Parameters:
  ///   - rawValue: The string value of the comment.
  ///   - kind: The kind of comment.
  init(rawValue: String, kind: Kind?) {
    self.init(rawValue: rawValue)
    self.kind = kind
  }
}

// MARK: - ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible

extension Comment: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {
  public init(stringLiteral: String) {
    self.init(rawValue: stringLiteral, kind: .stringLiteral)
  }

  public var description: String {
    rawValue
  }
}

// MARK: - Equatable, Hashable, Comparable

extension Comment: Equatable, Hashable {}

// MARK: - Codable

extension Comment: Codable {}

extension Comment.Kind: Codable {}

// MARK: - Trait, TestTrait, SuiteTrait

extension Comment: TestTrait, SuiteTrait {
  public var comments: [Comment] {
    [self]
  }
}

@_spi(Experimental)
extension Trait where Self == Comment {
  /// Construct a comment related to a test.
  ///
  /// This function may be used to provide context or background information
  /// about a test's purpose, explain how a complex test operates, or include
  /// details which may be helpful when diagnosing issues recorded by a test.
  ///
  /// - Parameters:
  ///   - comment: The comment about the test.
  ///
  /// - Returns: An instance of ``Comment`` containing the specified
  ///   comment.
  ///
  /// - Note: This function is not intended to reference bugs related to a test.
  ///   Instead, use ``Trait/bug(_:_:)``, ``Trait/bug(_:id:_:)-10yf5``, or
  ///   ``Trait/bug(_:id:_:)-3vtpl``.
  public static func comment(_ comment: String) -> Self {
    Self(rawValue: comment, kind: .trait)
  }
}

// MARK: -

extension Test {
  /// The complete set of comments about this test from all of its traits.
  public var comments: [Comment] {
    traits.flatMap(\.comments)
  }

  /// The complete set of comments about this test from all traits of the given
  /// type.
  ///
  /// - Parameters:
  ///   - traitType: The type of ``Trait`` for which comments should be returned.
  ///
  /// - Returns: The comments about this test for the specified test trait type.
  @_spi(Experimental)
  public func comments<T>(from traitType: T.Type) -> [Comment] where T: Trait {
    traits.lazy
      .compactMap { $0 as? T }
      .flatMap(\.comments)
  }
}
