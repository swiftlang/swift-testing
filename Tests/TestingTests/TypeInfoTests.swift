//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ForToolsIntegrationOnly) import Testing

@Suite("TypeInfo Tests")
struct TypeInfoTests {
  @Test(arguments: [
    (
      String.self,
      TypeInfo(qualifiedTypeName: "Swift.String", unqualifiedTypeName: "String")
    ),
    (
      [String].self,
      TypeInfo(qualifiedTypeName: "Swift.Array<Swift.String>", unqualifiedTypeName: "Array<String>")
    ),
    (
      [Test].self,
      TypeInfo(qualifiedTypeName: "Swift.Array<Testing.Test>", unqualifiedTypeName: "Array<Test>")
    ),
    (
      (key: String, value: Int).self,
      TypeInfo(qualifiedTypeName: "(key: Swift.String, value: Swift.Int)", unqualifiedTypeName: "(key: String, value: Int)")
    ),
    (
      (() -> String).self,
      TypeInfo(qualifiedTypeName: "() -> Swift.String", unqualifiedTypeName: "() -> String")
    ),
  ] as [(Any.Type, TypeInfo)])
  func initWithType(type: Any.Type, expectedTypeInfo: TypeInfo) {
    let typeInfo = TypeInfo(type)
    #expect(typeInfo == expectedTypeInfo)
  }
}
