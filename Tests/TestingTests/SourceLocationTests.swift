//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ExperimentalEventHandling) @_spi(ExperimentalTestRunning) import Testing

@Suite("SourceLocation Tests")
struct SourceLocationTests {
  @Test("SourceLocation.description property")
  func sourceLocationDescription() {
    let sourceLocation = SourceLocation()
    _ = String(describing: sourceLocation)
    _ = String(reflecting: sourceLocation)
  }

  @Test("SourceLocation.fileID property")
  func sourceLocationFileID() {
    let sourceLocation = SourceLocation()
    #expect(sourceLocation.fileID.hasSuffix("/SourceLocationTests.swift"))
  }

  @Test("SourceLocation.fileName property")
  func sourceLocationFileName() {
    var sourceLocation = SourceLocation()
    #expect(sourceLocation.fileName == "SourceLocationTests.swift")

    sourceLocation.fileID = "FakeModule/FakeFileID"
    #expect(sourceLocation.fileName == "FakeFileID")
  }

  @Test("SourceLocation.moduleName property")
  func sourceLocationModuleName() {
    var sourceLocation = SourceLocation()
    #expect(!sourceLocation.moduleName.contains("/"))
    #expect(!sourceLocation.moduleName.isEmpty)

    sourceLocation.fileID = "FakeModule/FakeFileID"
    #expect(sourceLocation.moduleName == "FakeModule")
  }

  @Test("SourceLocation.fileID property ignores middle components")
  func sourceLocationFileIDMiddleIgnored() {
    let sourceLocation = SourceLocation(fileID: "A/B/C/D.swift")
    #expect(sourceLocation.moduleName == "A")
    #expect(sourceLocation.fileName == "D.swift")
  }

  @Test("SourceLocation.line and .column properties")
  func sourceLocationLineAndColumn() {
    var sourceLocation = SourceLocation()
    #expect(sourceLocation.line > 0)
    #expect(sourceLocation.line < 500)
    #expect(sourceLocation.column > 0)
    #expect(sourceLocation.column < 80)

    sourceLocation.line = 12345
    #expect(sourceLocation.line == 12345)
    sourceLocation.column = 2468
    #expect(sourceLocation.column == 2468)
  }

  @Test("SourceLocation._filePath property")
  func sourceLocationFilePath() {
    var sourceLocation = SourceLocation()
    #expect(sourceLocation._filePath == #filePath)

    sourceLocation._filePath = "A"
    #expect(sourceLocation._filePath == "A")
  }

  @Test("SourceLocation comparisons")
  func comparisons() {
    do {
      let loc1 = SourceLocation(fileID: "A/B", line: 1, column: 1)
      let loc2 = SourceLocation(fileID: "A/C", line: 1, column: 1)
      #expect(loc1 < loc2)
    }

    do {
      let loc1 = SourceLocation(fileID: "A/B", line: 1, column: 1)
      let loc2 = SourceLocation(fileID: "A/B", line: 2, column: 1)
      #expect(loc1 < loc2)
    }

    do {
      let loc1 = SourceLocation(fileID: "A/B", line: 1, column: 1)
      let loc2 = SourceLocation(fileID: "A/B", line: 1, column: 2)
      #expect(loc1 < loc2)
    }

    do {
      let loc1 = SourceLocation(fileID: "A/B", line: 1, column: 2)
      let loc2 = SourceLocation(fileID: "A/B", line: 2, column: 1)
      #expect(loc1 < loc2)
    }

    do {
      let loc1 = SourceLocation(fileID: "A/B", line: 2, column: 1)
      let loc2 = SourceLocation(fileID: "A/C", line: 1, column: 1)
      #expect(loc1 < loc2)
    }

    do {
      let loc1 = SourceLocation(fileID: "A/B", line: 1, column: 2)
      let loc2 = SourceLocation(fileID: "A/C", line: 1, column: 1)
      #expect(loc1 < loc2)
    }

    do {
      let loc1 = SourceLocation(fileID: "A/B", filePath: "A", line: 1, column: 1)
      let loc2 = SourceLocation(fileID: "A/B", filePath: "B", line: 1, column: 1)
      #expect(loc1 == loc2)
    }
  }

  @Test("Custom source location argument to #expect()")
  func customSourceLocationArgument() async {
    await confirmation("Source location matched custom") { sourceLocationMatched in
      let lineNumber = Int.random(in: 999_999 ..< 1_999_999)

      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        guard case let .issueRecorded(issue) = event.kind else {
          return
        }
        if issue.sourceLocation?.line == lineNumber {
          sourceLocationMatched()
        }
      }
      await Test {
        #expect(Bool(false), sourceLocation: SourceLocation(fileID: "A/B", line: lineNumber))
      }.run(configuration: configuration)
    }
  }
}
