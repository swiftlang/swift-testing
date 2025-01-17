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

    let value = try #require(Expression.Value(reflecting: foo))
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

    let value = try #require(Expression.Value(reflecting: x))
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

    let value = try #require(Expression.Value(reflecting: x))
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

    let value = try #require(Expression.Value(reflecting: recursiveItem))
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

    let value = try #require(Expression.Value(reflecting: one))
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

  @Test("Value reflecting an object with two back-references to itself",
        .bug("https://github.com/swiftlang/swift-testing/issues/785#issuecomment-2440222995"))
  func multipleSelfReferences() throws {
    class A {
      weak var one: A?
      weak var two: A?
    }

    let a = A()
    a.one = a
    a.two = a

    let value = try #require(Expression.Value(reflecting: a))
    #expect(value.children?.count == 2)
  }

  @Test("Value reflecting an object in a complex graph which includes back-references",
        .bug("https://github.com/swiftlang/swift-testing/issues/785"))
  func complexObjectGraphWithCyclicReferences() throws {
    class A {
      var c1: C!
      var c2: C!
      var b: B!
    }
    class B {
      weak var a: A!
      var c: C!
    }
    class C {
      weak var a: A!
    }

    let a = A()
    let b = B()
    let c = C()
    a.c1 = c
    a.c2 = c
    a.b = b
    b.a = a
    b.c = c
    c.a = a

    let value = try #require(Expression.Value(reflecting: a))
    #expect(value.children?.count == 3)
  }

  @Test("Value reflection can be disabled via Configuration")
  func valueReflectionDisabled() {
    var configuration = Configuration.current ?? .init()
    configuration.valueReflectionOptions = nil
    Configuration.withCurrent(configuration) {
      #expect(Expression.Value(reflecting: "hello") == nil)
    }
  }

  @Test("Value reflection truncates large values")
  func reflectionOfLargeValues() throws {
    struct Large {
      var foo: Int?
      var bar: [Int]
    }

    var configuration = Configuration.current ?? .init()
    var options = configuration.valueReflectionOptions ?? .init()
    options.maximumCollectionCount = 2
    options.maximumChildDepth = 2
    configuration.valueReflectionOptions = options

    try Configuration.withCurrent(configuration) {
      let large = Large(foo: 123, bar: [4, 5, 6, 7])
      let value = try #require(Expression.Value(reflecting: large))

      #expect(!value.isTruncated)
      do {
        let fooValue = try #require(value.children?.first)
        #expect(!fooValue.isTruncated)
        let fooChildren = try #require(fooValue.children)
        try #require(fooChildren.count == 1)
        let fooChild = try #require(fooChildren.first)
        #expect(fooChild.isTruncated)
        #expect(fooChild.children == nil)
      }
      do {
        let barValue = try #require(value.children?.last)
        #expect(barValue.isTruncated)
        #expect(barValue.children?.count == 3)
        let lastBarChild = try #require(barValue.children?.last)
        #expect(String(describing: lastBarChild) == "(2 out of 4 elements omitted for brevity)")
      }
    }
  }

  @Test("Value reflection max collection count only applies to collections")
  func reflectionMaximumCollectionCount() throws {
    struct X {
      var a = 1
      var b = 2
      var c = 3
      var d = 4
    }

    var configuration = Configuration.current ?? .init()
    var options = configuration.valueReflectionOptions ?? .init()
    options.maximumCollectionCount = 2
    configuration.valueReflectionOptions = options

    try Configuration.withCurrent(configuration) {
      let x = X()
      let value = try #require(Expression.Value(reflecting: x))
      #expect(!value.isTruncated)
      #expect(value.children?.count == 4)
    }
  }

  @Test("Value describing a simple struct")
  func describeSimpleStruct() {
    struct Foo {
      var x: Int = 123
    }

    let foo = Foo()
    let value = Expression.Value(describing: foo)
    #expect(String(describing: value) == "Foo(x: 123)")
    #expect(value.children == nil)
  }

}
