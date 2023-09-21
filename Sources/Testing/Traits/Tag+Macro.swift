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
  /// Copy a tag and attach its source code representation.
  ///
  /// - Parameters:
  ///   - tag: The tag to copy.
  ///   - sourceCode: The source code of `tag` if available at compile time.
  ///
  /// - Returns: A copy of `tag` with `sourceCode` attached.
  ///
  /// - Warning: This function is used to implement the `@Test` macro. Do not
  ///   call it directly.
  public static func __tag(_ tag: Tag, sourceCode: SourceCode) -> Self {
    var tagCopy = tag
    tagCopy.sourceCode = sourceCode
    return tagCopy
  }

  /// Forward a sequence of tags.
  ///
  /// - Parameters:
  ///   - tags: The sequence to forward.
  ///
  /// - Returns: A copy of `tags`.
  ///
  /// This function exists to ensure that expressions like
  /// `.tags(someFunctionReturningATagArray())` remain syntactically valid after
  /// macro expansion occurs.
  ///
  /// - Warning: This function is used to implement the `@Test` macro. Do not
  ///   call it directly.
  public static func __tag(_ tags: some Sequence<Tag>, sourceCode: SourceCode) -> some Sequence<Tag> {
    tags
  }
}
