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
  /// Initialize an instance of this type with the given placeholder string.
  ///
  /// - Parameters:
  ///   - placeholder: The placeholder string, not including surrounding angle
  ///     brackets or pound characters.
  init(_ placeholder: String) {
    self.init(placeholder: .identifier("<# \(placeholder) #" + ">"))
  }
}
