//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftSyntax

extension EditorPlaceholderExprSyntax {
  /// Initialize an instance of this type with the given placeholder string and
  /// optional type.
  ///
  /// - Parameters:
  ///   - placeholder: The placeholder string, not including surrounding angle
  ///     brackets or pound characters.
  ///   - type: The type which this placeholder have, if any. When non-`nil`,
  ///     the expression will use typed placeholder syntax.
  init(_ placeholder: String, type: String? = nil) {
    self.init(placeholder: .identifier(_editorPlaceholder(placeholder, type: type)))
  }

  /// Initialize an instance of this type with the given type, using that as the
  /// placeholder string.
  ///
  /// - Parameters:
  ///   - type: The type to use both as the placeholder text and as the
  ///     expression's type.
  init(type: String) {
    self.init(placeholder: .identifier(editorPlaceholder(forType: type)))
  }
}

/// Format a string to be included in an editor placeholder expression using the
/// specified placeholder text and optional type information.
///
/// - Parameters:
///   - placeholder: The placeholder string, not including surrounding angle
///     brackets or pound characters.
///   - type: The type which this placeholder have, if any. When non-`nil`,
///     the expression will use typed placeholder syntax.
///
/// - Returns: A formatted editor placeholder string.
private func _editorPlaceholder(_ placeholder: String, type: String? = nil) -> String {
  let placeholderContent = if let type {
    // These use typed placeholder syntax, which allows the compiler to
    // type-check the expression successfully. The resulting code still does
    // not compile due to the placeholder, but it makes the diagnostic more
    // clear. See
    // https://developer.apple.com/documentation/swift-playgrounds/specifying-editable-regions-in-a-playground-page#Mark-Editable-Areas-with-Placeholder-Tokens
    if placeholder == type {
      // When the placeholder string is exactly the same as the type string,
      // use the shorter typed placeholder format.
      "T##\(placeholder)"
    } else {
      "T##\(placeholder)##\(type)"
    }
  } else {
    placeholder
  }

  // Manually concatenate the string to avoid it being interpreted as a
  // placeholder when editing this file.
  return "<#\(placeholderContent)#" + ">"
}

/// Format a string to be included in an editor placeholder expression using the
/// specified type, using that type as the placeholder text.
///
/// - Parameters:
///   - type: The type to use both as the placeholder text and as the
///     expression's type.
///
/// - Returns: A formatted editor placeholder string.
func editorPlaceholder(forType type: String) -> String {
  _editorPlaceholder(type, type: type)
}
