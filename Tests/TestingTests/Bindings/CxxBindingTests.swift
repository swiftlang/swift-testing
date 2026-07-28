//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
import _TestingInternals

struct `C++ Binding Tests` {
  @Test func `can discover example library`() async throws {
    let library = try #require(Library(named: "ExampleCxxBinding"))
    #expect(library.displayName == "Example C++ Binding")
    let result = await library.callEntryPoint()
    #expect(result == EXIT_SUCCESS)
  }
}
