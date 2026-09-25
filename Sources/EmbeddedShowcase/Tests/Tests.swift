//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Testing

// A minimal set of tests used to confirm that a whole program which links Swift
// Testing can be built for an Embedded Swift target.

extension Tag {
  @Tag static var foo: Self
}

@Test(.tags(.foo)) func addition() {
  #expect(1 + 1 == 2)
}

@Test func subtraction() {
  #expect(5 - 3 == 2)
}

@Test(arguments: 0 ..< 5)
func isSmall(_ i: Int) {
  #expect(i < 5)
}

@Test func multiplication() {
  #expect(6 * 7 == 42)
}

@Test func willFail() {
  #expect(123 == 456, "Math, am I right?")

  struct MyError: Error {}
  #expect(throws: Never.self) {
    throw MyError()
  }

  Issue.record("This is just a friendly warning.", severity: .warning)
}

@Test func recordAttachment() {
  let loremIpsum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
  Attachment.record(loremIpsum, named: "Lorem Ipsum.txt")
}
