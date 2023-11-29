//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if swift(>=5.11)
import SwiftSyntax
#else
public import SwiftSyntax
#endif

extension TokenSyntax {
  /// The text of this instance with all backticks removed.
  ///
  /// - Bug: This property works around the presence of backticks in `text.`
  ///   ([swift-syntax-#1936](https://github.com/apple/swift-syntax/issues/1936))
  var textWithoutBackticks: String {
    text.filter { $0 != "`" }
  }
}
