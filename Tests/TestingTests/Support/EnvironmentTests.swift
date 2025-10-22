//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) import Testing
private import _TestingInternals

@Suite("Environment Tests", .serialized)
struct EnvironmentTests {
  var name = "SWT_ENVIRONMENT_VARIABLE_FOR_TESTING"

  @Test("Get whole environment block")
  func getWholeEnvironment() throws {
    let value = "\(UInt64.random(in: 0 ... .max))"
    try #require(Environment.setVariable(value, named: name))
    defer {
      Environment.setVariable(nil, named: name)
    }
    let env = Environment.get()
    #expect(env[name] == value)
  }

  @Test("Read environment variable")
  func readEnvironmentVariable() throws {
    let value = "\(UInt64.random(in: 0 ... .max))"
    try #require(nil == Environment.variable(named: name))
    defer {
      Environment.setVariable(nil, named: name)
    }
    try #require(Environment.setVariable(value, named: name))
    #expect(Environment.variable(named: name) == value)
  }

  @Test("Read true environment flags",
    arguments: [
      "1", String(describing: UInt64.max), String(describing: Int64.min),
      String(describing: UInt64.random(in: 1 ... .max)), String(describing: Int64.random(in: .min ..< 0)),
      "YES", "yes", "yEs", "TRUE", "true", "tRuE",
    ]
  )
  func readTrueFlag(value: String) throws {
    try #require(nil == Environment.variable(named: name))
    defer {
      Environment.setVariable(nil, named: name)
    }
    try #require(Environment.setVariable(value, named: name))
    #expect(Environment.variable(named: name) == value)
    #expect(Environment.flag(named: name) == true)
  }

  @Test("Read false environment flags",
    arguments: [
      "0", "", " ", "\t",
      "NO", "no", "nO", "FALSE", "false", "fAlSe",
      "alphabetical", "ümlaut", "😀",
    ]
  )
  func readFalseFlag(value: String) throws {
    try #require(nil == Environment.variable(named: name))
    defer {
      Environment.setVariable(nil, named: name)
    }
    try #require(Environment.setVariable(value, named: name))
    #expect(Environment.variable(named: name) == value)
    #expect(Environment.flag(named: name) == false)
  }
}
