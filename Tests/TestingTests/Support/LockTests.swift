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

@Suite("@Locked Tests")
struct LockTests {
  @Test("Mutating a value within withLock(_:)")
  func locking() {
    @Locked
    var value = 0

    #expect(value == 0)
    $value.withLock { value in
      value = 1
    }
    #expect(value == 1)
  }
}
