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

@Suite("Test.ID.Selection Tests")
struct Test_ID_SelectionTests {
  @Test("Single-element key path")
  func singleElementKeyPath() {
    let selection = Test.ID.Selection(testIDs: [["A"]])
    #expect(selection.contains(["A"]))
    #expect(!selection.contains(["X"]))
  }

  @Test("One-element key path before two-element key path")
  func oneElementKeyPathBeforeTwoElementKeyPath() {
    let selection = Test.ID.Selection(testIDs: [["A"], ["A", "B"]])
    #expect(selection.contains(["A"]))
    #expect(selection.contains(["A", "B"]))
    #expect(selection.contains(["A", "B", "C"]))
    #expect(selection.contains(["A", "X"]))
    #expect(selection.contains(["A", "X", "Y"]))
    #expect(!selection.contains(["X"]))
  }

  @Test("Two-element key path before one-element key path")
  func twoElementKeyPathBeforeOneElementKeyPath() {
    let selection = Test.ID.Selection(testIDs: [["A", "B"], ["A"]])
    #expect(selection.contains(["A"]))
    #expect(selection.contains(["A", "B"]))
    #expect(selection.contains(["A", "B", "C"]))
    #expect(selection.contains(["A", "X"]))
    #expect(selection.contains(["A", "X", "Y"]))
    #expect(!selection.contains(["X"]))
  }

  @Test("Two peer key paths")
  func twoPeerKeyPaths() {
    let selection = Test.ID.Selection(testIDs: [["A", "B"], ["A", "C"]])
    #expect(selection.contains(["A"]))
    #expect(selection.contains(["A", "B"]))
    #expect(selection.contains(["A", "B", "D"]))
    #expect(selection.contains(["A", "C"]))
    #expect(!selection.contains(["A", "X"]))
    #expect(!selection.contains(["A", "X", "Y"]))
    #expect(!selection.contains(["X"]))
  }

  @Test("Short key path before long key path")
  func shortKeyPathBeforeLongKeyPath() {
    let selection = Test.ID.Selection(testIDs: [["A", "B"], ["A", "B", "C", "D"]])
    #expect(selection.contains(["A"]))
    #expect(selection.contains(["A", "B"]))
    #expect(selection.contains(["A", "B", "J"]))
    #expect(selection.contains(["A", "B", "C"]))
    #expect(selection.contains(["A", "B", "C", "D"]))
    #expect(selection.contains(["A", "B", "C", "D", "E"]))
    #expect(!selection.contains(["A", "X"]))
    #expect(!selection.contains(["A", "X", "Y"]))
    #expect(!selection.contains(["X"]))
  }

  @Test("Long key path before short key path")
  func longKeyPathBeforeShortKeyPath() {
    let selection = Test.ID.Selection(testIDs: [["A", "B", "C", "D"], ["A", "B"]])
    #expect(selection.contains(["A"]))
    #expect(selection.contains(["A", "B"]))
    #expect(selection.contains(["A", "B", "J"]))
    #expect(selection.contains(["A", "B", "C"]))
    #expect(selection.contains(["A", "B", "C", "D"]))
    #expect(selection.contains(["A", "B", "C", "D", "E"]))
    #expect(!selection.contains(["A", "X"]))
    #expect(!selection.contains(["A", "X", "Y"]))
    #expect(!selection.contains(["X"]))
  }

  @Test("Long key path, then short key path, then medium key path")
  func longKeyPathThenShortKeyPathThenMediumKeyPath() {
    let selection = Test.ID.Selection(testIDs: [["A", "B", "C", "D", "E"], ["A"], ["A", "B", "C"]])
    #expect(selection.contains(["A"]))
    #expect(selection.contains(["A", "B"]))
    #expect(selection.contains(["A", "B", "J"]))
    #expect(selection.contains(["A", "B", "C"]))
    #expect(selection.contains(["A", "B", "C", "D"]))
    #expect(selection.contains(["A", "B", "C", "D", "E"]))
    #expect(selection.contains(["A", "B", "C", "D", "E", "F"]))
    #expect(selection.contains(["A", "X"]))
    #expect(selection.contains(["A", "X", "Y"]))
    #expect(!selection.contains(["X"]))
  }

  @Test("Inverted lookup")
  func invertedLookup() {
    let selection = Test.ID.Selection(testIDs: [["A", "B", "C", "D", "E"], ["A", "B", "C"]])
    #expect(!selection.contains(["A"], inferAncestors: false))
    #expect(!selection.contains(["A", "B"], inferAncestors: false))
    #expect(!selection.contains(["A", "B", "J"], inferAncestors: false))
    #expect(selection.contains(["A", "B", "C"], inferAncestors: false))
    #expect(selection.contains(["A", "B", "C", "D"], inferAncestors: false))
    #expect(selection.contains(["A", "B", "C", "D", "E"], inferAncestors: false))
    #expect(selection.contains(["A", "B", "C", "D", "E", "F"], inferAncestors: false))
    #expect(!selection.contains(["A", "X"], inferAncestors: false))
    #expect(!selection.contains(["A", "X", "Y"], inferAncestors: false))
    #expect(!selection.contains(["X"], inferAncestors: false))
  }
}
