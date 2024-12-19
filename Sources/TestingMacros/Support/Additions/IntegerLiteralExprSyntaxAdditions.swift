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

extension IntegerLiteralExprSyntax {
  init(_ value: some BinaryInteger, radix: IntegerLiteralExprSyntax.Radix = .decimal) {
    let stringValue = "\(radix.literalPrefix)\(String(value, radix: radix.size))"
    self.init(literal: .integerLiteral(stringValue))
  }
}
