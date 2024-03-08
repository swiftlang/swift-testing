//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import Testing

@Suite("zip Tests")
struct ZipTests {
  @Test("Zipped collections are not combinatoric")
  func zippedCollections() async throws {
    await confirmation("correct number of iterations", expectedCount: 10) { testCaseStarted in
      await Test(arguments: zip("ABCDEFGHIJ", 0 ..< 10)) { _, _ in
        testCaseStarted()
      }.run()
    }
  }

  @Test("All elements of two ranges are equal", arguments: zip(0 ..< 10, 0 ..< 10))
  func allElementsEqual(i: Int, j: Int) {
    #expect(i == j)
  }
}
