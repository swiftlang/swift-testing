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

struct `Iterable Argument Tests` {
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
  @Test(arguments: [MoveOnlyArgumentValue(x: 123)] as InlineArray)
  func `Move-only argument value`(_ value: borrowing MoveOnlyArgumentValue) {
    #expect(value.x == 123)
  }

  @available(_iterableAPI, *)
  static func uniqueArray() -> UniqueArray<MoveOnlyArgumentValue> {
    var result = UniqueArray<MoveOnlyArgumentValue>()
    for _ in 0 ..< 3 {
      result.append(MoveOnlyArgumentValue(x: 123))
    }
    return result
  }

  @available(_iterableAPI, *)
  @Test(arguments: uniqueArray())
  func `Argument values in UniqueArray`(_ value: borrowing MoveOnlyArgumentValue) {
    #expect(value.x == 123)
  }

  @available(_iterableAPI, *)
  struct MyIterable: Iterable {
    var elements: [Int]

    @_lifetime(borrow self)
    func makeBorrowingIterator() -> Span<Int>.BorrowingIterator {
      let span = elements.span
      return _overrideLifetime(span.makeBorrowingIterator(), borrowing: self)
    }
  }

  @available(_iterableAPI, *)
  @Test(arguments: MyIterable(elements: [1, 2, 3]))
  func `Argument values with custom iterable type`(_ value: Int) {
    #expect(value > 0)
    #expect(value < 4)
  }
}
