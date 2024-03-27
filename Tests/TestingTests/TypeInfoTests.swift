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
      TypeInfo(fullyQualifiedName: "Swift.String", unqualifiedName: "String")
    ),
    (
      [String].self,
      TypeInfo(fullyQualifiedName: "Swift.Array<Swift.String>", unqualifiedName: "Array<String>")
    ),
    (
      [Test].self,
      TypeInfo(fullyQualifiedName: "Swift.Array<Testing.Test>", unqualifiedName: "Array<Test>")
    ),
    (
      (key: String, value: Int).self,
      TypeInfo(fullyQualifiedName: "(key: Swift.String, value: Swift.Int)", unqualifiedName: "(key: String, value: Int)")
    ),
    (
      (() -> String).self,
      TypeInfo(fullyQualifiedName: "() -> Swift.String", unqualifiedName: "() -> String")
    ),
  ] as [(Any.Type, TypeInfo)])
  func initWithType(type: Any.Type, expectedTypeInfo: TypeInfo) {
    let typeInfo = TypeInfo(describing: type)
    #expect(typeInfo == expectedTypeInfo)
  }

  @Test func typeNameInExtensionIsMungedCorrectly() {
    #expect(_typeName(String.NestedType.self, qualified: true) == "(extension in TestingTests):Swift.String.NestedType")
    #expect(TypeInfo(describing: String.NestedType.self).fullyQualifiedName == "Swift.String.NestedType")
  }

  @Test func typeNameOfFunctionIsMungedCorrectly() {
    typealias T = (Int, String) -> Bool
    #expect(TypeInfo(describing: T.self).fullyQualifiedName == "(Swift.Int, Swift.String) -> Swift.Bool")
  }
}

// MARK: - Fixtures

extension String {
  enum NestedType {}
}
