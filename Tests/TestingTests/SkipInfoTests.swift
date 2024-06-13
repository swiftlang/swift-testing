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

@Suite("SkipInfo Tests")
struct SkipInfoTests {
  @Test("comment property") func comment() {
    var skipInfo = SkipInfo(comment: "abc123")
    #expect(skipInfo.comment == "abc123")
    skipInfo.comment = .__line("// Foo")
    #expect(skipInfo.comment == .__line("// Foo"))
  }

  @Test("sourceLocation property") func sourceLocation() {
    let sourceLocation1 = #_sourceLocation
    var skipInfo = SkipInfo(sourceContext: .init(sourceLocation: sourceLocation1))
    #expect(skipInfo.sourceLocation == sourceLocation1)

    let sourceLocation2 = #_sourceLocation
    skipInfo.sourceLocation = sourceLocation2
    #expect(skipInfo.sourceLocation == sourceLocation2)
  }
}
