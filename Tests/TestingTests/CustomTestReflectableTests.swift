//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) import Testing

struct `CustomTestReflectable Tests` {
  @Test func `Can get a custom mirror from a value`() throws {
    let subject = MyReflectable() as Any
    let mirror = Mirror(reflectingForTest: subject)
    #expect(mirror.children.count == 4)
    let fee = try #require(mirror.children.first)
    #expect(fee.label == "fee")
    #expect(fee.value is Int)
  }

  @Test func `Fall back to Mirror(reflecting:)`() throws {
    let subject = [1, 2, 3] as Any
    let mirror = Mirror(reflectingForTest: subject)
    #expect(mirror.children.count > 0)
  }
}

// MARK: - Fixtures

struct MyReflectable: CustomTestReflectable {
  var customTestMirror: Mirror {
    Mirror(
      self,
      children: [
        (label: "fee", value: 1 as Any),
        (label: "fi", value: 2.0 as Any),
        (label: "fo", value: "3" as Any),
        (label: "fum", value: /4/ as Any)
      ]
    )
  }
}
