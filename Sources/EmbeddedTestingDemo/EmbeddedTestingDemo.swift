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

@Test func addition() {
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
