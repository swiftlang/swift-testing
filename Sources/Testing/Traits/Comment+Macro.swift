//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Trait where Self == Comment {
  /// Construct a comment related to a test from a single-line source code
  /// comment near it.
  ///
  /// - Parameters:
  ///   - comment: The comment about the test.
  ///
  /// - Returns: An instance of ``Comment`` containing the specified comment.
  ///
  /// - Warning: This function is used to implement the `@Test` macro. Do not
  ///   call it directly.
  public static func __line(_ comment: String) -> Self {
    Self(rawValue: comment, kind: .line)
  }

  /// Construct a comment related to a test from a source code block comment
  /// near it.
  ///
  /// - Parameters:
  ///   - comment: The comment about the test.
  ///
  /// - Returns: An instance of ``Comment`` containing the specified comment.
  ///
  /// - Warning: This function is used to implement the `@Test` macro. Do not
  ///   call it directly.
  public static func __block(_ comment: String) -> Self {
    Self(rawValue: comment, kind: .block)
  }

  /// Construct a comment related to a test from a single-line
  /// [Markup](https://github.com/swiftlang/swift/blob/main/docs/DocumentationComments.md)
  /// comment near it.
  ///
  /// - Parameters:
  ///   - comment: The comment about the test.
  ///
  /// - Returns: An instance of ``Comment`` containing the specified comment.
  ///
  /// - Warning: This function is used to implement the `@Test` macro. Do not
  ///   call it directly.
  public static func __documentationLine(_ comment: String) -> Self {
    Self(rawValue: comment, kind: .documentationLine)
  }

  /// Construct a comment related to a test from a
  /// [Markup](https://github.com/swiftlang/swift/blob/main/docs/DocumentationComments.md)
  /// block comment near it.
  ///
  /// - Parameters:
  ///   - comment: The comment about the test.
  ///
  /// - Returns: An instance of ``Comment`` containing the specified comment.
  ///
  /// - Warning: This function is used to implement the `@Test` macro. Do not
  ///   call it directly.
  public static func __documentationBlock(_ comment: String) -> Self {
    Self(rawValue: comment, kind: .documentationBlock)
  }
}
