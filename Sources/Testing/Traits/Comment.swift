//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type representing a comment related to a test.
///
/// This type may be used to provide context or background information about a
/// test's purpose, explain how a complex test operates, or include details
/// which may be helpful when diagnosing issues recorded by a test.
///
/// To add a comment to a test or suite, add a code comment before its `@Test`
/// or `@Suite` attribute. See <doc:AddingComments> for more details.
///
/// - Note: This type is not intended to reference bugs related to a test.
///   Instead, use ``Trait/bug(_:_:)``, ``Trait/bug(_:id:_:)-10yf5``, or
///   ``Trait/bug(_:id:_:)-3vtpl``.
public struct Comment: RawRepresentable, Sendable {
  /// The single comment string contained in this instance.
  ///
  /// To obtain the complete set of comments applied to a test, see
  /// ``Test/comments``.
  public var rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// An enumeration describing the possible kind of a comment.
  @_spi(ForToolsIntegrationOnly)
  public enum Kind: Sendable {
    /// This comment came from a single-line comment in the test's source code
    /// starting with `//`.
    case line

    /// This comment came from a block comment in the test's source code
    /// starting with `/*` and ending with `*/`.
    case block

    /// This comment came from a single-line [Markup](https://github.com/swiftlang/swift/blob/main/docs/DocumentationComments.md)
    /// comment in the test's source code starting with `///`.
    case documentationLine

    /// This comment came from a block [Markup](https://github.com/swiftlang/swift/blob/main/docs/DocumentationComments.md)
    /// comment in the test's source code starting with `/**` and ending with
    /// `*/`.
    case documentationBlock

    /// This comment came from an explicit call to ``Trait/comment(_:)``.
    case trait

    /// This comment was initialized from a string literal.
    case stringLiteral
  }

  /// The kind of this comment, if known.
  ///
  /// If this instance was created with a call to ``init(rawValue:)``, the value
  /// of this property is `nil`. Otherwise, it can be used to determine which
  /// kind of comment is represented.
  @_spi(ForToolsIntegrationOnly)
  public var kind: Kind?

  /// Initialize an instance of this type.
  ///
  /// - Parameters:
  ///   - rawValue: The string value of the comment.
  ///   - kind: The kind of comment.
  init(rawValue: String, kind: Kind?) {
    self.init(rawValue: rawValue)
    self.kind = kind
  }
}

// MARK: - ExpressibleByStringLiteral, CustomStringConvertible

extension Comment: ExpressibleByStringLiteral, CustomStringConvertible {
  public init(stringLiteral: String) {
    self.init(rawValue: stringLiteral, kind: .stringLiteral)
  }

  public var description: String {
    rawValue
  }
}

// MARK: - ExpressibleByStringInterpolation

extension Comment: ExpressibleByStringInterpolation {
  public init(stringInterpolation: StringInterpolation) {
    self.init(rawValue: stringInterpolation.rawValue)
  }

  /// The string interpolation handler type for ``Comment``.
  @_documentation(visibility: private)
  public struct StringInterpolation: StringInterpolationProtocol, Sendable {
    /// Storage for the string constructed by this instance.
    ///
    /// `DefaultStringInterpolation` in the Swift standard library also simply
    /// accumulates its result in a string.
    @usableFromInline var rawValue: String = ""

    @inlinable public init(literalCapacity: Int, interpolationCount: Int) {}

    @inlinable public mutating func appendLiteral(_ literal: String) {
      rawValue += literal
    }

    @inlinable public mutating func appendInterpolation(_ value: some Any) {
      rawValue += String(describingForTest: value)
    }

    @inlinable public mutating func appendInterpolation(_ value: (some Any)?) {
      // This overload is provided so that the compiler does not emit warnings
      // about optional values in string interpolations (which we are fine with
      // when constructing Comment instances.)
      rawValue += String(describingForTest: value)
    }
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

  /// The complete set of comments about this test from all traits of a certain
  /// type.
  ///
  /// - Parameters:
  ///   - traitType: The type of ``Trait`` whose comments should be returned.
  ///
  /// - Returns: The comments found for the specified test trait type.
  @_spi(Experimental)
  public func comments<T>(from traitType: T.Type) -> [Comment] where T: Trait {
    traits.lazy
      .compactMap { $0 as? T }
      .flatMap(\.comments)
  }
}
