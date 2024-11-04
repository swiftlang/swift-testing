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
private import _TestingInternals

@Suite("TypeInfo Tests")
struct TypeInfoTests {
  @Test(arguments: [
    (
      String.self,
      TypeInfo(fullyQualifiedName: "Swift.String", unqualifiedName: "String", mangledName: "")
    ),
    (
      [String].self,
      TypeInfo(fullyQualifiedName: "Swift.Array<Swift.String>", unqualifiedName: "Array<String>", mangledName: "")
    ),
    (
      [Test].self,
      TypeInfo(fullyQualifiedName: "Swift.Array<Testing.Test>", unqualifiedName: "Array<Test>", mangledName: "")
    ),
    (
      (key: String, value: Int).self,
      TypeInfo(fullyQualifiedName: "(key: Swift.String, value: Swift.Int)", unqualifiedName: "(key: String, value: Int)", mangledName: "")
    ),
    (
      (() -> String).self,
      TypeInfo(fullyQualifiedName: "() -> Swift.String", unqualifiedName: "() -> String", mangledName: "")
    ),
  ])
  func initWithType(type: Any.Type, expectedTypeInfo: TypeInfo) {
    let typeInfo = TypeInfo(describing: type)
    #expect(typeInfo == expectedTypeInfo)
  }

  @Test func typeNameInExtensionIsMungedCorrectly() {
    #expect(String(reflecting: String.NestedType.self) == "(extension in TestingTests):Swift.String.NestedType")
    #expect(TypeInfo(describing: String.NestedType.self).fullyQualifiedName == "Swift.String.NestedType")
  }

  @Test func typeNameOfFunctionIsMungedCorrectly() {
    typealias T = (Int, String) -> Bool
    #expect(TypeInfo(describing: T.self).fullyQualifiedName == "(Swift.Int, Swift.String) -> Swift.Bool")
  }

  @available(_mangledTypeNameAPI, *)
  @Test func mangledTypeName() {
    #expect(_mangledTypeName(String.self) == TypeInfo(describing: String.self).mangledName)
    #expect(_mangledTypeName(String.NestedType.self) == TypeInfo(describing: String.NestedType.self).mangledName)
    #expect(_mangledTypeName(SomeEnum.self) == TypeInfo(describing: SomeEnum.self).mangledName)
  }

  @available(_mangledTypeNameAPI, *)
  @Test func isImportedFromC() {
    #expect(!TypeInfo(describing: String.self).isImportedFromC)
    #expect(TypeInfo(describing: SWTTestEnumeration.self).isImportedFromC)
  }

  @available(_mangledTypeNameAPI, *)
  @Test func isSwiftEnumeration() {
    #expect(!TypeInfo(describing: String.self).isSwiftEnumeration)
    #expect(TypeInfo(describing: SomeEnum.self).isSwiftEnumeration)
  }
}

// MARK: - Fixtures

extension String {
  enum NestedType {}
}

private enum SomeEnum {}
