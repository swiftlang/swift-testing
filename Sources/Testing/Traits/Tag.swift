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

// MARK: - Color tags

extension Tag {
  /// A tag representing the color red.
  public static var red: Self { "red" }

  /// A tag representing the color orange.
  public static var orange: Self { "orange" }

  /// A tag representing the color yellow.
  public static var yellow: Self { "yellow" }

  /// A tag representing the color green.
  public static var green: Self { "green" }

  /// A tag representing the color blue.
  public static var blue: Self { "blue" }

  /// A tag representing the color purple.
  public static var purple: Self { "purple" }

  /// Whether or not this tag represents a color predefined by the testing
  /// library.
  ///
  /// Color tags are any of these values:
  ///
  /// - ``Tag/red``
  /// - ``Tag/orange``
  /// - ``Tag/yellow``
  /// - ``Tag/green``
  /// - ``Tag/blue``
  /// - ``Tag/purple``
  public var isColor: Bool {
    switch self {
    case .red, .orange, .yellow, .green, .blue, .purple:
      return true
    default:
      return false
    }
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
  /// The index of this color, relative to other colors.
  ///
  /// The value of this property can be used for sorting color tags distinctly
  /// from other (string-based) tags.
  private var _colorIndex: Int? {
    switch self {
    case .red:
      return 0
    case .orange:
      return 1
    case .yellow:
      return 2
    case .green:
      return 3
    case .blue:
      return 4
    case .purple:
      return 5
    default:
      return nil
    }
  }

  public static func <(lhs: Tag, rhs: Tag) -> Bool {
    switch (lhs._colorIndex, rhs._colorIndex) {
    case let (.some(lhs), .some(rhs)):
      return lhs < rhs
    case (.some, .none):
      return true
    case (.none, .some):
      return false
    default:
      return lhs.rawValue < rhs.rawValue
    }
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
