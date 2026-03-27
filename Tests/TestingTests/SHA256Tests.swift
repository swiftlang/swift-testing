//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014–2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(CryptoKit)

import CryptoKit
import Testing

@Suite
struct SHA256Tests {
  @Test(arguments: [
    [],
    withUnsafeBytes(of: UInt64.random(in: 0 ..< .max), Array.init),
    Array(0..<20),
    Array("Hello, world".utf8),
    Array(#"{"key": "value", "key2": 123, "key3": null}"#.utf8),
    (0..<1_024).map { _ in .random(in: 0 ..< .max) }
  ])
  func matchesCryptoKit(data: [UInt8]) {
    let expected = CryptoKit::SHA256.hash(data: data)
    let ours = Testing::SHA256.hash(data)

    #expect(expected == ours, "Data \(data) did not hash to the same value")
  }
  }
}

#endif
