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
/// To apply tags to a test, use one of the following functions:
///
/// - ``Trait/tags(_:)-505n9``
/// - ``Trait/tags(_:)-yg0i``
public struct Tag: Sendable {
  /// An enumeration describing the various kinds of tag that can be applied to
  /// a test.
  @_spi(ForToolsIntegrationOnly)
  public enum Kind: Sendable, Hashable {
    /// The tag is a static member of ``Tag`` such as ``Tag/red``, declared
    /// using the ``Tag()`` macro.
    ///
    /// - Parameters:
    ///   - name: The (almost) fully-qualified name of the static member. The
    ///     leading `"Testing.Tag."` is not included as it is redundant.
    case staticMember(_ name: String)

    /// The tag is a string literal declared directly in source.
    ///
    /// - Parameters:
    ///   - stringLiteral: The string literal specified by the test author.
    case stringLiteral(_ stringLiteral: String)
  }

  /// The kind of this tag.
  @_spi(ForToolsIntegrationOnly)
  public var kind: Kind

  @_spi(ForToolsIntegrationOnly)
  public init(kind: Kind) {
    self.kind = kind
  }

  /// Initialize an instance of this type from a string provided by a user, for
  /// instance at the command line using `swift test`.
  ///
  /// - Parameters:
  ///   - stringValue: The user-supplied string value.
  ///
  /// Use this initializer when a user has provided an arbitrary string and it
  /// is necessary to convert it into a tag. A simple heuristic is applied such
  /// that the resulting instance may represent a (possibly non-existent) static
  /// member of ``Tag`` or may represent a string literal.
  @_spi(ForToolsIntegrationOnly)
  public init(userProvidedStringValue stringValue: String) {
    self.init(_codableStringValue: stringValue)
  }
}

// MARK: - CustomStringConvertible

extension Tag: CustomStringConvertible {
  public var description: String {
    switch kind {
    case let .staticMember(name):
      ".\(name)"
    case let .stringLiteral(stringLiteral):
      #""\#(stringLiteral)""#
    }
  }
}

// MARK: - Equatable, Hashable, Comparable

extension Tag: Equatable, Hashable, Comparable {
  public static func <(lhs: Tag, rhs: Tag) -> Bool {
    switch (lhs.kind, rhs.kind) {
    case let (.staticMember(lhs), .staticMember(rhs)):
      lhs < rhs
    case let (.stringLiteral(lhs), .stringLiteral(rhs)):
      lhs < rhs

    // (Arbitrarily) sort static members before string literals.
    case (.staticMember, .stringLiteral):
      true
    case (.stringLiteral, .staticMember):
      false
    }
  }
}

// MARK: - Codable, CodingKeyRepresentable

extension Tag: Codable, CodingKeyRepresentable {
  /// Initialize an instance of this type from a string previously encoded from
  /// the `_codableStringValue` property.
  ///
  /// - Parameters:
  ///   - stringValue: The previously-encoded string.
  private init(_codableStringValue stringValue: String) {
    if stringValue.first == "." {
      self.init(kind: .staticMember(String(stringValue.dropFirst())))
    } else if stringValue.first == #"\"# {
      self.init(kind: .stringLiteral(String(stringValue.dropFirst())))
    } else {
      self.init(kind: .stringLiteral(stringValue))
    }
  }

  public init(from decoder: any Decoder) throws {
    let stringValue = try String(from: decoder)
    self.init(_codableStringValue: stringValue)
  }

  /// This instance represented as a string, suitable for encoding.
  private var _codableStringValue: String {
    switch kind {
    case let .staticMember(name):
      ".\(name)"
    case let .stringLiteral(stringLiteral):
      if stringLiteral.first == "." || stringLiteral.first == #"\"# {
        #"\\#(stringLiteral)"#
      } else {
        stringLiteral
      }
    }
  }

  public func encode(to encoder: any Encoder) throws {
    try _codableStringValue.encode(to: encoder)
  }

  /// A type describing a generic coding key.
  ///
  /// This type is used to implement `Codable` conformance for ``Tag`` so that
  /// it can be used as a dictionary key.
  private struct _CodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
      self.stringValue = stringValue
    }

    init?(intValue: Int) {
      nil // Unsupported
    }
  }

  @available(macOS 12.3, iOS 15.4, watchOS 8.5, tvOS 15.4, *)
  public var codingKey: any CodingKey {
    _CodingKey(stringValue: _codableStringValue)
  }

  @available(macOS 12.3, iOS 15.4, watchOS 8.5, tvOS 15.4, *)
  public init?<T>(codingKey: T) where T : CodingKey {
    self.init(_codableStringValue: codingKey.stringValue)
  }
}

// MARK: -

extension Test {
  /// The complete, unique set of tags associated with this test.
  ///
  /// Tags are associated with tests using one of the following functions:
  ///
  /// - ``Trait/tags(_:)-505n9``
  /// - ``Trait/tags(_:)-yg0i``
  public var tags: Set<Tag> {
    traits.lazy
      .compactMap { $0 as? Tag.List }
      .map(\.tags)
      .reduce(into: []) { $0.formUnion($1) }
  }
}
