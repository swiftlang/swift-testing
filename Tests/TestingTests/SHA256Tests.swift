//
//  SHA256Tests.swift
//  swift-testing
//
//  Created by Harlan Haskins on 3/26/26.
//

#if canImport(CryptoKit)

import CryptoKit
import Testing
import _TestingUtilities

@Suite
struct SHA256Tests {
  @Test(arguments: [
    [],
    Array(0..<20),
    Array("Hello, world".utf8),
    Array(#"{"key": "value", "key2": 123, "key3": null}"#.utf8)
  ])
  func matchesCryptoKit(data: [UInt8]) {
    let expected = CryptoKit::SHA256.hash(data: data)
    let ours = _TestingUtilities::SHA256.hash(data)

    #expect(expected == ours)
  }
}

#endif
