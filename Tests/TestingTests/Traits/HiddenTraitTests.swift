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

@Suite("Hidden Trait Tests", .tags("trait"))
struct HiddenTraitTests {
  @Test(".hidden trait")
  func hiddenTrait() throws {
    let test = Test(.hidden) {}
    #expect(test.isHidden)
  }
}
