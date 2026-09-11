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

@Suite struct Arithmetic {
  @Test func multiplication() {
    #expect(6 * 7 == 42)
  }
}

/// The main entry point for this executable target.
///
/// This runs the tests declared above using the same entry point that Swift
/// Package Manager uses. An explicit (empty) arguments value is passed so that
/// the testing library does not try to read command-line arguments, which are
/// not generally available on an Embedded Swift target.
@main struct EmbeddedTestingDemo {
  static func main() async {
    await Testing.__swiftPMEntryPoint(passing: .init()) as Never
  }
}
