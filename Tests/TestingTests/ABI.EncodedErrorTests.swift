//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

#if !SWT_NO_ABI_JSON_SCHEMA
@Suite struct `ABI.EncodedError Tests` {
  struct FakeError: Error {
    var localizedDescription: String {
      "Some synthetic error"
    }
  }

  private let error = ABI.EncodedError<ABI.CurrentVersion>(encoding: FakeError())

  @Test func `Encodes a Swift error`() throws {
    #expect(error.domain == "TestingTests.`ABI.EncodedError Tests`.FakeError")
    #expect(error.description == "FakeError()")
    #expect(error.code == 1)
  }

  @Test func `Decodes all optional error fields `() throws {
    let encodedData = Array(
      """
      {}
      """.utf8)
    let decoded = try encodedData.withUnsafeBytes { encodedData in
      try JSON.decode(ABI.EncodedError<ABI.CurrentVersion>.self, from: encodedData)
    }

    #expect(decoded.description == nil)
    #expect(decoded.domain == nil)
    #expect(decoded.code == nil)
    #expect(decoded.typeInfo == nil)
  }

  @Test func `Expected field names`() throws {
    let error = ABI.EncodedError<ABI.CurrentVersion>(encoding: FakeError())

    try JSON.withEncoding(of: error) { buf in
      let str = String(decoding: buf, as: UTF8.self)
      #expect(str.contains(#""code":"#))
      #expect(str.contains(#""domain":"#))
      #expect(str.contains(#""description":"#))
      #expect(str.contains(#""type":"#))
    }
  }

  @Test func `Round-trips through JSON`() throws {
    let encoded = ABI.EncodedError<ABI.CurrentVersion>(encoding: FakeError())
    let decoded = try JSON.encodeAndDecode(encoded)

    #expect(decoded.description == encoded.description)
    #expect(decoded.domain == encoded.domain)
    #expect(decoded.code == encoded.code)
    #expect(decoded.typeInfo != nil)
  }
}
#endif
