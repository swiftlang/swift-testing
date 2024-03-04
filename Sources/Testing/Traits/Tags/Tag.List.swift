//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Tag {
  /// A type representing one or more tags applied to a test.
  ///
  /// To add this trait to a test, use one of the following functions:
  ///
  /// - ``Trait/tags(_:)-505n9``
  /// - ``Trait/tags(_:)-yg0i``
  public struct List {
    /// The list of tags contained in this instance.
    ///
    /// This preserves the list of the tags exactly as they were originally
    /// specified, in their original order, including duplicate entries. To
    /// access the complete, unique set of tags applied to a ``Test``, see
    /// ``Test/tags``.
    public var tags: [Tag]

    /// Initialize an instance of this type with the specified tags.
    ///
    /// - Parameters:
    ///   - tags: The tags to include in the new instance. See ``tags``.
    init(tags: some Sequence<Tag>) {
      self.tags = Array(tags)
    }
  }
}

// MARK: - Equatable, Hashable, Comparable

extension Tag.List: Equatable, Hashable {}

// MARK: - CustomStringConvertible

extension Tag.List: CustomStringConvertible {
  public var description: String {
    tags.lazy
      .map(String.init(describing:))
      .joined(separator: ", ")
  }
}

// MARK: - Trait, TestTrait, SuiteTrait

extension Tag.List: TestTrait, SuiteTrait {
  public var isRecursive: Bool {
    true
  }
}

extension Trait where Self == Tag.List {
  /// Construct a list of tags to apply to a test.
  ///
  /// - Parameters:
  ///   - tags: The list of tags to apply to the test.
  ///
  /// - Returns: An instance of ``Tag/List`` containing the specified tags.
  public static func tags(_ tags: Tag...) -> Self {
    Self(tags: tags)
  }

  /// Construct a list of tags to apply to a test from a list of string values.
  ///
  /// - Parameters:
  ///   - stringValues: The list of string values to convert to tags and apply
  ///     to the test.
  ///
  /// - Returns: An instance of ``Tag/List`` containing the specified string
  ///   literals as tags.
  ///
  /// This function is provided as a convenience to allow specifying tags as
  /// string values. To specify a mix of tags identified by symbol (such as
  /// ``Tag/red``) and tags identified by string value (such as `"important"`),
  /// use two separate calls to this function and pass symbols separately from
  /// string values:
  ///
  /// ```swift
  /// @Test("Wheels spin", .tags("mechanical"), .tags(.critical))
  /// func wheelsSpin() {}
  /// ```
  public static func tags(_ stringValues: _const String...) -> Self {
    Self(tags: stringValues.map { Tag(kind: .stringLiteral($0)) })
  }
}
