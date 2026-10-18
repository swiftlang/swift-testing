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

    public init(literalCapacity: Int, interpolationCount: Int) {}

    @inlinable public mutating func appendLiteral(_ literal: String) {
      rawValue += literal
    }

    /// Append a value that may be an optional string.
    ///
    /// - Parameters:
    ///   - value: The value to append if it is an instance of `Optional<S>`
    ///     where `S: StringProtocol`.
    ///
    /// - Returns: Whether or not `value` was an optional string and was
    /// 	appended to this interpolation instance.
    ///
    /// We special-case strings to not include the quotation marks added by
    /// ``CustomTestStringConvertible`` (which in the context of interpolation
    /// probably violate the Principle of Least Surprise).
    ///
    /// In Embedded Swift, this function only handles `String` and `Substring`
    /// because casts to protocol existentials are disallowed.
    private mutating func _appendPossibleStringOptional(_ value: (some Any)?) -> Bool {
      func append(_ value: (some StringProtocol)?) -> Bool {
        if let value {
          rawValue += value
        } else {
          rawValue += _OptionalNilComparisonType.testDescription
        }
        return true
      }
      if let value = value as? String? {
        return append(value)
      } else if let value = value as? Substring? {
        return append(value)
      }
#if !hasFeature(Embedded)
      if let value = value as? any StringProtocol? {
        let value = value.map { String($0) }
        return append(value)
      }
#endif
      return false
    }

    /// Append the description of a given value to this interpolation, using a
    /// lazily-computed fallback description after special cases are considered.
    ///
    /// - Parameters:
    /// 	- value: The value to describe.
    ///   - description: A string describing `value`, used if no special cases
    ///   	apply to `value`.
    @usableFromInline mutating func appendInterpolation(_ value: (some Any)?, description: @autoclosure () -> String) {
      if _appendPossibleStringOptional(value) {
        return
      }

      // No special cases applied.
      rawValue += description()
    }

#if !hasFeature(Embedded)
    @inlinable public mutating func appendInterpolation(_ value: (some Any)?) {
      appendInterpolation(value, description: String(describingForTest: value))
    }
#else
    @inlinable public mutating func appendInterpolation(_ value: some CustomTestStringConvertible) {
      appendInterpolation(value, description: String(describingForTest: value))
    }

    @inlinable public mutating func appendInterpolation(_ value: some CustomStringConvertible & CustomTestStringConvertible) {
      appendInterpolation(value, description: String(describingForTest: value))
    }

    @inlinable public mutating func appendInterpolation(_ value: some CustomStringConvertible) {
      appendInterpolation(value, description: String(describingForTest: value))
    }

    @inlinable public mutating func appendInterpolation(_ value: some CustomDebugStringConvertible & CustomTestStringConvertible) {
      appendInterpolation(value, description: String(describingForTest: value))
    }

    @inlinable public mutating func appendInterpolation(_ value: some CustomDebugStringConvertible) {
      appendInterpolation(value, description: String(describingForTest: value))
    }

    @inlinable public mutating func appendInterpolation(_ value: some CustomStringConvertible & CustomDebugStringConvertible & CustomTestStringConvertible) {
      appendInterpolation(value, description: String(describingForTest: value))
    }

    @inlinable public mutating func appendInterpolation(_ value: some CustomStringConvertible & CustomDebugStringConvertible) {
      appendInterpolation(value, description: String(describingForTest: value))
    }

    @_disfavoredOverload
    @available(*, deprecated, message: "String representations of arbitrary values are not supported in Embedded Swift")
    mutating func appendInterpolation(_ value: borrowing some ~Copyable & ~Escapable) {
      appendInterpolation(UnavailableInEmbeddedSwift(), description: UnavailableInEmbeddedSwift.testDescription)
    }

    mutating func appendInterpolation(_ value: (some ~Copyable & ~Escapable).Type) {
      appendInterpolation(value, description: String(describingForTest: value))
    }

    mutating func appendInterpolation(_ value: any Error) {
      appendInterpolation(value as any Error, description: String(describingForTest: value))
    }
#endif
  }
}

// MARK: - Equatable, Hashable, Comparable

extension Comment: Equatable, Hashable {}

#if !SWT_NO_CODABLE
// MARK: - Codable

extension Comment: Codable {}
extension Comment.Kind: Codable {}
#endif

// MARK: - Trait, TestTrait, SuiteTrait

extension Comment: TestTrait {
  public var comments: [Comment] {
    [self]
  }
}

#if !hasFeature(Embedded)
extension Comment: SuiteTrait {}
#endif

// MARK: -

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
    traits.flatMap { $0.comments }
  }
}
