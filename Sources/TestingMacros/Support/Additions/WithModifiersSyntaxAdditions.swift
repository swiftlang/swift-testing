//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import SwiftSyntax

extension WithModifiersSyntax {
  /// Whether or not this node is `static` or `class`.
  var isStaticOrClass: Bool {
    modifiers.lazy
      .map(\.name.tokenKind)
      .contains { $0 == .keyword(.class) || $0 == .keyword(.static) }
  }

  /// Whether or not this node is `mutating`.
  var isMutating: Bool {
    modifiers.lazy
      .map(\.name.tokenKind)
      .contains(.keyword(.mutating))
  }

  /// Whether or not this node is `nonisolated`.
  var isNonisolated: Bool {
    modifiers.lazy
      .map(\.name.tokenKind)
      .contains(.keyword(.nonisolated))
  }
}
