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

@Suite("Expression.Value Tests")
struct Expression_ValueTests {

  @Test("Value reflecting a simple struct with one property")
  func simpleStruct() throws {
    struct Foo {
      var x: Int = 123
    }

    let foo = Foo()

    let value = Expression.Value(reflecting: foo)
    let children = try #require(value.children)
    try #require(children.count == 1)

    let child = try #require(children.first)
    #expect(child.label == "x")
    #expect(child.typeInfo == TypeInfo(describing: Int.self))
    #expect(String(describing: child) == "123")
    #expect(child.children == nil)
  }

  @Test("Value reflecting an object with multiple non-cyclic references")
  func multipleNonCyclicReferences() throws {
    class C: CustomStringConvertible {
      var one: C?
      var two: C?
      let description: String

      init(description: String) {
        self.description = description
      }
    }

    let x = C(description: "x")
    let y = C(description: "y")
    x.one = y
    x.two = y

    let value = Expression.Value(reflecting: x)
    let children = try #require(value.children)
    try #require(children.count == 3)

    let one = try #require(value.children?[0].children?.first)
    #expect(String(describing: one) == "y")

    let two = try #require(value.children?[1].children?.first)
    #expect(String(describing: two) == "y")
  }

  @Test("Value reflecting an object with multiple cyclic references")
  func multipleCyclicReferences() throws {
    class C: CustomStringConvertible {
      var one: C?
      weak var two: C?
      let description: String

      init(description: String) {
        self.description = description
      }
    }

    let x = C(description: "x")
    let y = C(description: "y")
    x.one = y
    x.two = y
    y.two = x

    let value = Expression.Value(reflecting: x)
    let children = try #require(value.children)
    try #require(children.count == 3)

    do {
      let one = try #require(value.children?[0].children?.first)
      #expect(String(describing: one) == "y")

      let oneChildren = try #require(one.children)
      try #require(oneChildren.count == 3)
      try #require(oneChildren[1].label == "two")

      let childlessX = try #require(oneChildren[1].children?.first)
      #expect(String(describing: childlessX) == "x")
    }
    do {
      let two = try #require(value.children?[1].children?.first)
      #expect(String(describing: two) == "y")

      let twoChildren = try #require(two.children)
      try #require(twoChildren.count == 3)
      try #require(twoChildren[1].label == "two")

      let childlessX = try #require(twoChildren[1].children?.first)
      #expect(String(describing: childlessX) == "x")
    }
  }

  @Test("Value reflecting an object with a cyclic reference to itself")
  func recursiveObjectReference() throws {
    class RecursiveItem {
      weak var anotherItem: RecursiveItem?
      let boolValue = false
    }

    let recursiveItem = RecursiveItem()
    recursiveItem.anotherItem = recursiveItem

    let value = Expression.Value(reflecting: recursiveItem)
    let children = try #require(value.children)
    try #require(children.count == 2)

    let firstChild = try #require(children.first)
    #expect(firstChild.label == "anotherItem")

    let lastChild = try #require(children.last)
    #expect(lastChild.label == "boolValue")
    #expect(String(describing: lastChild) == "false")
  }

  @Test("Value reflecting an object with a reference to another object which has a cyclic back-reference the first")
  func cyclicBackReference() throws {
    class One {
      var two: Two?
    }
    class Two {
      weak var one: One?
    }

    let one = One()
    let two = Two()
    one.two = two
    two.one = one

    let value = Expression.Value(reflecting: one)
    let children = try #require(value.children)
    try #require(children.count == 1)

    let twoChild = try #require(children.first)
    #expect(twoChild.label == "two")
    #expect(twoChild.typeInfo == TypeInfo(describing: Two?.self))
    let twoChildChildren = try #require(twoChild.children)
    try #require(twoChildChildren.count == 1)
    let twoChildChildrenOptionalChild = try #require(twoChildChildren.first)
    #expect(twoChildChildrenOptionalChild.label == "some")
    let twoChildChildrenOptionalChildren = try #require(twoChildChildrenOptionalChild.children)
    try #require(twoChildChildrenOptionalChildren.count == 1)

    let oneChild = try #require(twoChildChildrenOptionalChildren.first)
    #expect(oneChild.label == "one")
    #expect(oneChild.typeInfo == TypeInfo(describing: One?.self))
    let oneChildChildren = try #require(oneChild.children)
    try #require(oneChildChildren.count == 1)
    let oneChildChildrenOptionalChild = try #require(oneChildChildren.first)
    #expect(oneChildChildrenOptionalChild.label == "some")
    #expect(oneChildChildrenOptionalChild.children == nil)
  }

}
