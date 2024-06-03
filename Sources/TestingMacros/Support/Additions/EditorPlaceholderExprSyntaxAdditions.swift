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
  /// Initialize an instance of this type with the given display name string and
  /// optional type.
  ///
  /// - Parameters:
  ///   - displayName: The display name string, not including surrounding angle
  ///     brackets or pound characters.
  ///   - type: The type which this placeholder have, if any. When non-`nil`,
  ///     the expression will use typed placeholder syntax.
  init(_ displayName: String, type: String? = nil) {
    let placeholderString = if let type {
      // This uses typed placeholder syntax, which allows the compiler to
      // type-check the expression successfully. The resulting code still does
      // not compile due to the placeholder, but it makes the diagnostic more
      // clear. See
      // https://developer.apple.com/documentation/swift-playgrounds/specifying-editable-regions-in-a-playground-page#Mark-Editable-Areas-with-Placeholder-Tokens
      "T##\(displayName)##\(type)"
    } else {
      displayName
    }

    // Manually concatenate the string to avoid it being interpreted as a
    // placeholder when editing this file.
    self.init(placeholder: .identifier("<#\(placeholderString)#" + ">"))
  }
}
