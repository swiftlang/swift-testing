//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Testing

@Suite("Floating-point Accuracy Tests")
struct FloatingPointAccuracyTests {
  @Test("Equality with accuracy") func equality() {
    #expect((1.0 == 1.5) ± 0.5)
    #expect((1.0 == 1.5) +- 0.5)
  }

  @Test("Inequality with accuracy") func inequality() {
    #expect((1.0 != 1.5) ± 0.1)
    #expect((1.0 != 1.5) +- 0.1)
    withKnownIssue("Should fail") {
      #expect((1.0 == 1.5) ± 0.2)
    }
    withKnownIssue("Should fail") {
      #expect((1.0 != 1.5) ± 10.0)
    }
  }
}
