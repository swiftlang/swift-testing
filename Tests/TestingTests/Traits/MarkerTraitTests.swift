//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ForToolsIntegrationOnly) import Testing

@Suite("Marker Trait Tests", .tags(.traitRelated))
struct MarkerTraitTests {
  @Test("Equatable implementation")
  func equality() {
    let markerA = MarkerTrait(isRecursive: true)
    let markerB = MarkerTrait(isRecursive: true)
    let markerC = markerB
    #expect(markerA == markerA)
    #expect(markerA != markerB)
    #expect(markerB == markerC)
  }

  @Test(".hidden trait")
  func hiddenTrait() throws {
    do {
      let test = Test(/* no traits */) {}
      #expect(!test.isHidden)
    }
    do {
      let test = Test(.hidden) {}
      #expect(test.isHidden)
    }
  }

  @Test(".synthesized trait")
  func synthesizedTrait() throws {
    do {
      let test = Test(/* no traits */) {}
      #expect(!test.isSynthesized)
    }
    do {
      let test = Test(.synthesized) {}
      #expect(test.isSynthesized)
    }
  }
}
