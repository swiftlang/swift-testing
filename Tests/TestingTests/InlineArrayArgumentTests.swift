//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @testable import Testing

struct MoveOnlyArgumentValue: Sendable, ~Copyable {
  var x: Int
}

struct `InlineArray Argument Tests` {
  @available(_iterableAPI, *)
  @Test(arguments: [1, 2, 3] as InlineArray)
  func `Copyable argument value`(_ value: Int) {
    #expect(value > 0)
    #expect(value <= 3)
  }

  @available(_iterableAPI, *)
  @Test(arguments: [(1, 0xA), (2, 0xB), (3, 0xC)] as InlineArray)
  func `Copyable argument value as 2-tuple`(xy: (Int, Int8)) {
    #expect(xy.0 == Int(xy.1 - 0xA + 1))
  }

  @available(_iterableAPI, *)
  @Test(arguments: [(1, 0xA), (2, 0xB), (3, 0xC)] as InlineArray)
  func `Copyable argument value as desugared 2-tuple`(x: Int, y: Int8) {
    #expect(x == Int(y - 0xA + 1))
  }

  @available(_iterableAPI, *)
  @Test(arguments: [MoveOnlyArgumentValue(x: 123)])
  func `Move-only argument value`(_ value: borrowing MoveOnlyArgumentValue) {
    #expect(value.x == 123)
  }

  @available(_iterableAPI, *)
  @Test(arguments: [MoveOnlyArgumentValue(x: 4), MoveOnlyArgumentValue(x: 5), MoveOnlyArgumentValue(x: 6)], [1, 2, 3] as InlineArray)
  func `Multiple arguments (one move-only, one not)`(_ x: borrowing MoveOnlyArgumentValue, _ y: Int) {
    #expect(x.x > y)
  }
}
