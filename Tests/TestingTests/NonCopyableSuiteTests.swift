//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ForToolsIntegrationOnly) import Testing

@Suite("Non-Copyable Tests")
struct NonCopyableTests: ~Copyable {
  @Test static func staticMe() {}
  @Test borrowing func borrowMe() {}
  @Test consuming func consumeMe() {}
  @Test mutating func mutateMe() {}

  @Test borrowing func typeComparison() {
    let lhs = TypeInfo(describing: Self.self)
    let rhs = TypeInfo(describing: Self.self)

    #expect(lhs == rhs)
    #expect(lhs.hashValue == rhs.hashValue)
  }

  @available(_mangledTypeNameAPI, *)
  @Test borrowing func mangledTypeName() {
    #expect(TypeInfo(describing: Self.self).mangledName != nil)
  }
}
