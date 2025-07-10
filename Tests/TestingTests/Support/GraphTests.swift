//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import Testing

@Suite("Graph<K, V> Tests")
struct GraphTests {
  @Test("init(value:)")
  func basicInit() {
    let graph = Graph<String, Int>(value: 123)
    #expect(graph.value == 123)
    #expect(graph.children.isEmpty)
  }

  @Test("init() (sparse)")
  func optionalInit() {
    let graph = Graph<String, Int?>()
    #expect(graph.value == nil)
    #expect(graph.children.isEmpty)
  }

  @Test("init(value:children:)")
  func initWithChildren() {
    let graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    #expect(graph.value == 123)
    #expect(graph.children.count == 2)
    #expect(graph.children["C1"]?.value == 456)
    #expect(graph.children["C2"]?.value == 789)
    #expect(graph.children["C2"]?.children["C3"]?.value == 2468)
  }

  @Test("subgraph(at:)")
  func subgraphAt() {
    let graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    #expect(graph.subgraph(at: "C1")?.value == 456)
    #expect(graph.subgraph(at: "C2", "C3")?.value == 2468)
  }

  @Test func `subscript([K]) operator`() {
    let graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    #expect(graph["C2", "C3"] == 2468)
    #expect(graph["C0", "C2", "C3"] == nil)
    #expect(graph["C1", "C2", "C3"] == nil)
  }

  @Test("subscript([K]) operator (sparse)")
  func subscriptWithOptionals() {
    let graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: nil, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    #expect(graph["C2", "C3"] == 2468)
    #expect(graph["C0", "C2", "C3"] == nil)
    #expect(graph["C1", "C2", "C3"] == nil)
  }

  @Test("subscript([K]) operator (sparse, mutating)")
  func mutatingSubscriptWithOptionals() {
    var graph = Graph<String, Int?>()
    graph["C1", "C2", "C3", "C4", "C5"] = 123
    #expect(graph["C1"] == nil)
    #expect(graph["C1", "C2", "C3", "C4"] == nil)
    #expect(graph["C1", "C2", "C3", "C4", "C5"] == 123)
  }

  @Test("updateValue(_:at:) function")
  func update() {
    var graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    graph.updateValue(98765, at: ["C2", "C3"])
    #expect(graph["C2", "C3"] == 98765)
  }

  @Test("updateValue(_:at:) function (no existing value)")
  func updateWhereNoneExists() {
    var graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    let oldValue = graph.updateValue(98765, at: ["C2", "C3", "C4", "C5"])
    #expect(oldValue == nil)
  }

  @Test("insertValue(_:at:) function")
  func insert() {
    var graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    graph.insertValue(314159, at: ["C2", "C3", "C4"])
    #expect(graph.children["C2"]?.children["C3"]?.children["C4"]?.value == 314159)
    graph.forEach { _, value in
      // Shouldn't have actually inserted any nils here.
      #expect(value != nil)
    }
  }

  @Test("insertValue(_:at:) function (no existing value)")
  func insertWhereNoneExists() {
    var graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    let oldValue = graph.insertValue(314159, at: ["C2", "C3", "C4", "C5", "C6"], intermediateValue: 9999)
    #expect(oldValue == nil)
  }

  @Test("insertValue(_:at:) function (no existing value, sparse)")
  func insertOptionalWhereNoneExists() {
    var graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    let oldValue = graph.insertValue(314159, at: ["C2", "C3", "C4", "C5", "C6"])
    #expect(oldValue == nil)
  }

  @Test("removeValue(at:keepingChildren:) function")
  func removeKeepingChildren() {
    var graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    graph.removeValue(at: ["C2"], keepingChildren: true)
    let allValues = graph.compactMap(\.value).sorted(by: <)
    #expect(allValues == [123, 456, 2468])
  }

  @Test("removeValue(at:keepingChildren:) function (removing children)")
  func removeAndTheChildrenToo() {
    var graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    graph.removeValue(at: ["C2"], keepingChildren: false)
    let allValues = graph.compactMap(\.value).sorted(by: <)
    #expect(allValues == [123, 456])
  }

  @Test("removeValue(at:keepingChildren:) function (removing root, sparse)")
  func removingTheRootNodeWithOptionals() {
    var graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    graph.removeValue(at: [], keepingChildren: false)
    let allValues = graph.compactMap(\.value).sorted(by: <)
    #expect(allValues == [])
  }

  @Test("removeValue(at:keepingChildren:) function (removing root, should have no effect)")
  func removingTheRootNodeWithoutOptionalsDoesNothing() {
    var graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    graph.removeValue(at: [])
    let allValues = graph.map(\.value).sorted(by: <)
    #expect(allValues == [123, 456, 789, 2468])
  }

  @Test("removeValue(at:keepingChildren:) function (no value at key path)")
  func removeWhereNoneExists() {
    var graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])
    let removed = graph.removeValue(at: ["C1", "C99"], keepingChildren: false)
    #expect(removed == nil)
  }

  @Test("underestimatedCount and count properties")
  func counts() {
    let graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: nil, children: [
        "C2": Graph(value: 13579),
      ]),
      "C3": Graph(value: 789, children: [
        "C4": Graph(value: nil, children: [
          "C5": Graph(value: nil, children: [
            "C6": Graph(value: nil)
          ])
        ]),
      ]),
    ])
    #expect(graph.underestimatedCount == 3)
    #expect(graph.count == 7)
  }

  @Test("forEach(_:) function")
  func forEach() {
    let graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])

    var count = 0
    graph.forEach { _, value in
      #expect(value > 0)
      count += 1
    }
    #expect(count == 4)
  }

  @Test("forEach(_:) function (async)")
  func forEach_async() async {
    let graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456),
      "C2": Graph(value: 789, children: [
        "C3": Graph(value: 2468),
      ]),
    ])

    var count = 0
    await graph.forEach { _, value in
      // Ensure we can call async APIs from this transform closure
      func dummyAsyncFunc() async {}
      await dummyAsyncFunc()

      #expect(value > 0)
      count += 1
    }
    #expect(count == 4)
  }

  @Test("takeValues(at:) function")
  func takeValues() {
    let graph = Graph<String, Bool>(value: false, children: [
      "A": Graph(value: false, children: [
        "B": Graph(value: false, children: [
          "C": Graph(value: true),
        ]),
      ]),
    ])
    #expect(graph.takeValues(at: ["A", "C", "B"]).elementsEqual([false, nil, nil]))
  }

  @Test("compactMapValues(_:) function")
  func compactMapValues() throws {
    let graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: nil, children: [
        "C2": Graph(value: 13579),
      ]),
      "C3": Graph(value: 789, children: [
        "C4": Graph(value: nil),
      ]),
    ])

    let graph2 = try #require(graph.compactMapValues { keyPath, value in
      if value == 13579 {
        #expect(keyPath == ["C1", "C2"])
      } else if value == 789 {
        #expect(keyPath == ["C3"])
      }

      return value.map(-)
    })
    graph2.forEach { _, value in
      #expect(value < 0)
    }
    #expect(graph2.children["C3"]?.children.isEmpty == true)
    #expect(graph2.children["C3"]?.value == -789)
  }

  @Test("compactMapValues(_:) function (async)")
  func compactMapValues_async() async throws {
    let graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: nil, children: [
        "C2": Graph(value: 13579),
      ]),
      "C3": Graph(value: 789, children: [
        "C4": Graph(value: nil),
      ]),
    ])

    let mappedGraph = await graph.compactMapValues { keyPath, value in
      // Ensure we can call async APIs from this transform closure
      func dummyAsyncFunc() async {}
      await dummyAsyncFunc()

      if value == 13579 {
        #expect(keyPath == ["C1", "C2"])
      } else if value == 789 {
        #expect(keyPath == ["C3"])
      }

      return value.map(-)
    }

    let graph2 = try #require(mappedGraph)
    graph2.forEach { _, value in
      #expect(value < 0)
    }
    #expect(graph2.children["C3"]?.children.isEmpty == true)
    #expect(graph2.children["C3"]?.value == -789)
  }

  @Test("compactMapValues(_:) function (async, recursively applied)")
  func compactMapValuesWithRecursiveApplication_async() async throws {
    let graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: nil, children: [
        "C2": Graph(value: 13579),
      ]),
      "C3": Graph(value: 789, children: [
        "C4": Graph(value: nil),
      ]),
    ])

    let mappedGraph = await graph.compactMapValues { _, value in
      // Ensure we can call async APIs from this transform closure
      func dummyAsyncFunc() async {}
      await dummyAsyncFunc()

      if let value {
        if value == 789 {
          return (-value, recursivelyApply: true)
        }
        return (-value, recursivelyApply: false)
      }
      return nil
    }
    let graph2 = try #require(mappedGraph)
    graph2.forEach { _, value in
      #expect(value < 0)
    }
  }

  @Test("mapValues(_:) function")
  func mapValues() {
    let graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456, children: [
        "C2": Graph(value: 13579),
      ]),
      "C3": Graph(value: 789, children: [
        "C4": Graph(value: 2468),
      ]),
    ])

    let graph2 = graph.mapValues { -$1 }
    graph2.forEach { _, value in
      #expect(value < 0)
    }
    #expect(graph2.children["C3"]?.children["C4"]?.value == -2468)
  }

  @Test("mapValues(_:) function (async)")
  func mapValues_async() async {
    let graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456, children: [
        "C2": Graph(value: 13579),
      ]),
      "C3": Graph(value: 789, children: [
        "C4": Graph(value: 2468),
      ]),
    ])

    let graph2 = await graph.mapValues {
      // Ensure we can call async APIs from this transform closure
      func dummyAsyncFunc() async {}
      await dummyAsyncFunc()

      return -$1
    }
    graph2.forEach { _, value in
      #expect(value < 0)
    }
    #expect(graph2.children["C3"]?.children["C4"]?.value == -2468)
  }

  @Test("mapValues(_:) function (recursively applied)")
  func mapValuesWithRecursiveApplication() throws {
    let graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456, children: [
        "C2": Graph(value: 13579),
        "C3": Graph(value: 5050, children: [
          "C4": Graph(value: 25252525),
        ]),
      ]),
      "C5": Graph(value: 789, children: [
        "C6": Graph(value: 2468),
      ]),
    ])

    let graph2 = graph.mapValues {
      if $1 == 456 {
        return (999, true)
      }
      return ($1, false)
    }
    #expect(graph2.value != 999)
    #expect(graph2.children["C1"]?.value == 999)
    #expect(graph2.children["C1"]?.children["C2"]?.value == 999)
    #expect(graph2.children["C1"]?.children["C3"]?.value == 999)
    #expect(graph2.children["C1"]?.children["C3"]?.children["C4"]?.value == 999)
    #expect(graph2.children["C5"]?.value != 999)
    #expect(graph2.children["C5"]?.children["C6"]?.value != 999)
  }

  @Test("mapValues(_:) function (async, recursively applied)")
  func mapValuesWithRecursiveApplication_async() async throws {
    let graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456, children: [
        "C2": Graph(value: 13579),
        "C3": Graph(value: 5050, children: [
          "C4": Graph(value: 25252525),
        ]),
      ]),
      "C5": Graph(value: 789, children: [
        "C6": Graph(value: 2468),
      ]),
    ])

    let graph2 = await graph.mapValues {
      // Ensure we can call async APIs from this transform closure
      func dummyAsyncFunc() async {}
      await dummyAsyncFunc()

      if $1 == 456 {
        return (999, true)
      }
      return ($1, false)
    }
    #expect(graph2.value != 999)
    #expect(graph2.children["C1"]?.value == 999)
    #expect(graph2.children["C1"]?.children["C2"]?.value == 999)
    #expect(graph2.children["C1"]?.children["C3"]?.value == 999)
    #expect(graph2.children["C1"]?.children["C3"]?.children["C4"]?.value == 999)
    #expect(graph2.children["C5"]?.value != 999)
    #expect(graph2.children["C5"]?.children["C6"]?.value != 999)
  }

  @Test("map(_:) function")
  func map() {
    let graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456, children: [
        "C2": Graph(value: 13579),
      ]),
      "C3": Graph(value: 789, children: [
        "C4": Graph(value: 2468),
      ]),
    ])

    let values = graph.map { -$0.value }
    for value in [-123, -456, -13579, -789, -2468] {
      #expect(values.contains(value))
    }
  }

  @Test("compactMap(_:) function")
  func compactMap() {
    let graph = Graph<String, Int?>(value: 123, children: [
      "C1": Graph(value: nil, children: [
        "C2": Graph(value: 13579),
      ]),
      "C3": Graph(value: 789, children: [
        "C4": Graph(value: nil),
      ]),
    ])

    let values = graph.compactMap { $0.value.map(-) }
    for value in [-123, -13579, -789] {
      #expect(values.contains(value))
    }
  }

  @Test("flatMap(_:) function")
  func flatMap() {
    let graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456, children: [
        "C2": Graph(value: 13579),
      ]),
      "C3": Graph(value: 789, children: [
        "C4": Graph(value: 2468),
      ]),
    ])

    let values = graph.flatMap { [$0.value, $0.value + 1] }
    for value in [123, 124, 456, 457, 13579, 13580, 789, 790, 2468, 2469] {
      #expect(values.contains(value))
    }
  }

  @Test("flatMap(_:) function (async)")
  func flatMap_async() async {
    let graph = Graph<String, Int>(value: 123, children: [
      "C1": Graph(value: 456, children: [
        "C2": Graph(value: 13579),
      ]),
      "C3": Graph(value: 789, children: [
        "C4": Graph(value: 2468),
      ]),
    ])

    let values = await graph.flatMap {
      // Ensure we can call async APIs from this transform closure
      func dummyAsyncFunc() async {}
      await dummyAsyncFunc()

      return [$0.value, $0.value + 1]
    }
    #expect(Set(values) == [123, 124, 456, 457, 13579, 13580, 789, 790, 2468, 2469])
  }
}
