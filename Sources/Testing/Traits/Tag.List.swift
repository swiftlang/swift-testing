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
  /// To add this trait to a test, use ``Trait/tags(_:)``.
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
    tags.lazy.map { tag in
      if let expression = tag.expression {
        return String(describing: expression)
      } else if tag.isPredefinedColor {
        return ".\(tag.rawValue)"
      }
      return "\"\(tag.rawValue)\""
    }.joined(separator: ", ")
  }
}

// MARK: - Trait, TestTrait, SuiteTrait

extension Tag.List: TestTrait, SuiteTrait {
  public var isRecursive: Bool {
    true
  }

  public func _capturing(_ expression: @autoclosure () -> Expression) -> Self {
    guard case let .functionCall(_, _, arguments: arguments) = expression().kind else {
      return self
    }
    guard tags.count == arguments.count else {
      // There is a mismatch between the number of arguments and the number of
      // tags actually present, so bail.
      return self
    }

    let tags = zip(tags, arguments).lazy
      .map { tag, labelAndExpression in
        var tag = tag
        tag.expression = labelAndExpression.value
        return tag
      }
    return Self(tags: tags)
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
}
