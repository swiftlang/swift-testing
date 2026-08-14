//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ForToolsIntegrationOnly) import Testing

#if !SWT_NO_ABI_JSON_SCHEMA
@Suite struct `ABI.EncodedTypeInfo Tests` {
  @Test func `Encodes TypeInfo`() {
    let typeInfo = TypeInfo(describing: Bool.self)
    let encoded = ABI.EncodedTypeInfo<ABI.CurrentVersion>(encoding: typeInfo)

    #expect(encoded.fullyQualifiedName == "Swift.Bool")
    #expect(encoded.unqualifiedName == "Bool")
    #expect(encoded.mangledName == "$sSb")
  }

  @Test func `Round-trips through JSON`() throws {
    let typeInfo = TypeInfo(describing: Bool.self)
    let encoded = ABI.EncodedTypeInfo<ABI.CurrentVersion>(encoding: typeInfo)
    let decoded = try JSON.encodeAndDecode(encoded)

    #expect(decoded.fullyQualifiedName == encoded.fullyQualifiedName)
    #expect(decoded.unqualifiedName == encoded.unqualifiedName)
    #expect(decoded.mangledName == encoded.mangledName)
  }

  @Test func `Decode succeeds with missing fields`() throws {
    let encodedData = Array(
      """
      {
        "unqualifiedName": "string"
      }
      """.utf8)
    let decoded = try encodedData.withUnsafeBytes { encodedData in
      try JSON.decode(ABI.EncodedTypeInfo<ABI.CurrentVersion>.self, from: encodedData)
    }

    #expect(decoded.fullyQualifiedName == nil)
    #expect(decoded.unqualifiedName == "string")
    #expect(decoded.mangledName == nil)
  }

  @Test func `Round trips TypeInfo`() {
    let typeInfo = TypeInfo(describing: Bool.self)
    let encoded = ABI.EncodedTypeInfo<ABI.CurrentVersion>(encoding: typeInfo)
    let decoded = TypeInfo(decoding: encoded)

    #expect(typeInfo == decoded)
  }

  @Test func `Round trips TypeInfo with raw identifier name`() {
    struct `Period.Delimited.Type` {}
    let typeInfo = TypeInfo(describing: `Period.Delimited.Type`.self)
    let encoded = ABI.EncodedTypeInfo<ABI.CurrentVersion>(encoding: typeInfo)
    let decoded = TypeInfo(decoding: encoded)

    #expect(typeInfo == decoded)
  }
}
#endif
