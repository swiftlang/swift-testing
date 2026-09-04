//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ForToolsIntegrationOnly) @testable import Testing

private import _TestingInternals

struct `Color tests` {
#if !SWT_NO_FILE_IO && !SWT_NO_CODABLE
  @Test func `Colors are read from disk`() throws {
    let tempDirPath = try temporaryDirectory()
    let jsonPath = appendPathComponent("tag-colors.json", to: tempDirPath)
    var jsonContent = """
    {
    "alpha": "red",
    "beta": "#00CCFF",
    "gamma": "#AABBCC",
    "delta": null,

    "encode red": "red",
    "encode orange": "orange",
    "encode yellow": "yellow",
    "encode green": "green",
    "encode blue": "blue",
    "encode purple": "purple"
    }
    """
    try jsonContent.withUTF8 { jsonContent in
      let fileHandle = try Testing.FileHandle(forWritingAtPath: jsonPath)
      try fileHandle.write(jsonContent)
    }
    defer {
      _ = remove(jsonPath)
    }

    let tagColors = try loadTagColors(fromFileInDirectoryAtPath: tempDirPath)
    #expect(tagColors[Tag("alpha")] == .red)
    #expect(tagColors[Tag("beta")] == .rgb(0, 0xCC, 0xFF))
    #expect(tagColors[Tag("gamma")] == .rgb(0xAA, 0xBB, 0xCC))
    #expect(tagColors[Tag("delta")] == nil)

    #expect(tagColors[Tag("encode red")] == .red)
    #expect(tagColors[Tag("encode orange")] == .orange)
    #expect(tagColors[Tag("encode yellow")] == .yellow)
    #expect(tagColors[Tag("encode green")] == .green)
    #expect(tagColors[Tag("encode blue")] == .blue)
    #expect(tagColors[Tag("encode purple")] == .purple)
  }

  @Test func `No colors are read from a bad path`() throws {
    #expect(throws: (any Error).self) {
      try loadTagColors(fromFileInDirectoryAtPath: "Directory/That/Does/Not/Exist")
    }
  }

  @Test(arguments: [##""#NOTHEX""##, #""garbageColorName""#])
  func `Invalid color decoding`(colorJSON: String) throws {
    var colorJSON = colorJSON
    colorJSON.withUTF8 { colorJSON in
      _ = #expect(throws: (any Error).self) {
        _ = try JSON.decode(Color.self, from: .init(colorJSON))
      }
    }
  }
#endif

  @Test(
    arguments: [
      // Predefined colors (orange and purple are special-cased)
      (Color.red, 91), (.orange, 33), (.yellow, 93), (.green, 92), (.blue, 94), (.purple, 95),

      // Grays
      (.rgb(0, 0, 0), 30), (.rgb(255, 255, 255), 97), (.rgb(100, 100, 100), 90), (.rgb(200, 200, 200), 37),
      (.lightGray, 37), (.darkGray, 90),

      // Dark colors
      (.rgb(100, 0, 0), 31), (.rgb(100, 100, 0), 33), (.rgb(0, 100, 0), 32), (.rgb(0, 100, 100), 36), (.rgb(0, 0, 100), 34), (.rgb(100, 0, 100), 35),

      // Bright colors
      (.rgb(200, 0, 0), 91), (.rgb(200, 200, 0), 93), (.rgb(0, 200, 0), 92), (.rgb(0, 200, 200), 96), (.rgb(0, 0, 200), 94), (.rgb(200, 0, 200), 95),

      // Very dark colors
      (.rgb(1, 2, 3), 30), (.rgb(10, 11, 12), 30),
    ]
  )
  func `Colors are converted to 16-color correctly`(color: Color, expectedEscapeCode: Int) {
    let computedEscapeCode = color.closest16ColorEscapeCodeValue()
    #expect(computedEscapeCode == expectedEscapeCode)
  }

  @Test func `Color sorting`() {
    // By hue
    #expect(Color.rgb(200, 0, 0) < .rgb(0, 0, 200))
    // By saturation
    #expect(Color.rgb(100, 50, 50) < .rgb(100, 0, 0))
    // By value
    #expect(Color.rgb(0, 0, 0) < .rgb(100, 100, 100))
  }

  @Test func `Custom Event.Symbol color`() throws {
    let symbol = Event.Symbol.custom(
      unicodeCharacter: "A",
      windowsCharacter: "B",
      sfSymbolCharacter: "C",
      sfSymbolName: "D",
      color: .rgb(1, 2, 3)
    )
    let color = try #require(symbol.color)
    #expect(color == .rgb(1, 2, 3))
    #expect(color.closest16ColorEscapeCodeValue() == 30)
  }
}
