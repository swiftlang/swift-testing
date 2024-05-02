//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if compiler(>=5.11)
import SwiftSyntax
#else
public import SwiftSyntax
#endif

extension FloatingPoint where Self: LosslessStringConvertible {
  /// Initialize this instance from an expression representing a numeric value.
  ///
  /// - Parameters:
  ///   - numericLiteralExpr: The literal to convert to a floating-point value.
  ///
  /// If `numericLiteralExpr` was not an instance of `IntegerLiteralExprSyntax`
  /// or `FloatLiteralExprSyntax`, returns `nil`. Otherwise, `self` is
  /// initialized from the literal expression's underlying string.
  init?(_ numericLiteralExpr: some ExprSyntaxProtocol) {
    if let numberExpr = numericLiteralExpr.as(IntegerLiteralExprSyntax.self) {
      self.init(numberExpr.literal.textWithoutBackticks)
    } else if let numberExpr = numericLiteralExpr.as(FloatLiteralExprSyntax.self) {
      self.init(numberExpr.literal.textWithoutBackticks)
    } else {
      return nil
    }
  }
}
