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
@Suite struct `ABI.EncodedExpression Tests` {
  @Test func `Encodes a Swift expression`() throws {
    let expression = Expression("1 + 1")
    let encoded = ABI.EncodedExpression<ABI.CurrentVersion>(encoding: expression)

    #expect(encoded.sourceCode == "1 + 1")
    #expect(encoded.runtimeValue == nil)
    #expect(encoded.runtimeTypeName == nil)
    #expect(encoded.children == nil)
  }

  @Test func `Encodes an expression with a runtime value`() throws {
    let expression = Expression("1 + 1", runtimeValue: .init(describing: 2))
    let encoded = ABI.EncodedExpression<ABI.CurrentVersion>(encoding: expression)

    #expect(encoded.sourceCode == "1 + 1")
    #expect(encoded.runtimeValue == "2")
    #expect(encoded.runtimeTypeName == "Swift.Int")
    #expect(encoded.children == nil)
  }

  @Test func `Encodes an expression with children`() throws {
    let lhs = Expression("foo()", runtimeValue: .init(describing: 1))
    let rhs = Expression("bar()", runtimeValue: .init(describing: 1))
    let expression = Expression("foo() + bar()", runtimeValue: .init(describing: 2), subexpressions: [lhs, rhs])
    let encoded = ABI.EncodedExpression<ABI.CurrentVersion>(encoding: expression)

    #expect(encoded.children?.count == 2)
  }

  @Test func `Expected field names`() throws {
    let expression = Expression("1 + 1", runtimeValue: .init(describing: 2))
    let encoded = ABI.EncodedExpression<ABI.CurrentVersion>(encoding: expression)

    try JSON.withEncoding(of: encoded) { buf in
      let str = String(decoding: buf, as: UTF8.self)
      #expect(str.contains(#""sourceCode":"#))
      #expect(str.contains(#""value":"#))
      #expect(str.contains(#""type":"#))
    }
  }

  @Test func `Round-trips through JSON`() throws {
    let expression = Expression("1 + 1", runtimeValue: .init(describing: 2))
    let encoded = ABI.EncodedExpression<ABI.CurrentVersion>(encoding: expression)
    let decoded = try JSON.encodeAndDecode(encoded)

    #expect(decoded.sourceCode == encoded.sourceCode)
    #expect(decoded.runtimeValue == encoded.runtimeValue)
    #expect(decoded.runtimeTypeName == encoded.runtimeTypeName)
  }
}
#endif
