//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import Testing

struct PathTests {
  @Test func appendWithExistingTrailingSlash() {
    let path = Path("/hello/")
    let appendedPath = path.appending("world")
    #expect(appendedPath == "/hello/world")
  }

  @Test func appendWithNoExistingTrailingSlash() {
    let path = Path("/hello")
    let appendedPath = path.appending("world")
    #expect(appendedPath == "/hello/world")
  }

  @Test func appendToEmptyString() {
    let path = Path("")
    let appendedPath = path.appending("world")
    #expect(appendedPath == "world")
  }

  @Test func lastComponent() throws {
    let path = Path("/hello/world")
    let lastComponent = try #require(path.lastComponent)
    #expect(lastComponent == "world")
  }

  @Test func lastComponentWithTrailingSlash() throws {
    let path = Path("/hello/world/")
    let lastComponent = try #require(path.lastComponent)
    #expect(lastComponent == "world")
  }

  @Test func lastComponentOfEmptyString() {
    let path = Path("")
    #expect(path.lastComponent == nil)
  }

#if os(Windows)
#else
  @Test func appendToRoot() {
    let path = Path("/")
    let appendedPath = path.appending("world")
    #expect(appendedPath == "/world")
  }

  @Test func lastComponentOfRoot() {
    let path = Path("/")
    #expect(path.lastComponent == nil)
  }
#endif
}
