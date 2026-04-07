//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

#if canImport(Foundation)
private import Foundation
#endif

@Suite struct `ABI.EncodedTestTests` {
  let fixture = ABI.EncodedTest<ABI.CurrentVersion>(
    kind: .function,
    name: "TestName",
    sourceLocation: .init(),
    id: .init(encoding: .init([])))  // Blank placeholder; should be set in each test case

  /// Creates an EncodedTest.ID from a string.
  ///
  /// It doesn't really "decode" anything and just stores the string, so this
  /// should never throw in practice.
  func testID<V: ABI.Version>(_ string: String) throws -> ABI.EncodedTest<V>.ID {
    let data = try JSONEncoder().encode(string)
    return try JSONDecoder().decode(ABI.EncodedTest<V>.ID.self, from: data)
  }

  @Test func `Decode test components`() throws {
    var test = fixture
    test.id = try testID("Module.FooTests/testFunc()")

    let (module, components, function) = try #require(test.decodeIDComponents())
    #expect(module == "Module")
    #expect(components == ["FooTests"])
    #expect(function == "testFunc()")
  }

  @Test func `Decode suite components`() throws {
    var test = fixture
    test.kind = .suite
    test.id = try testID("Module.FooTests")

    let (module, components, function) = try #require(test.decodeIDComponents())
    #expect(module == "Module")
    #expect(components == ["FooTests"])
    #expect(function == nil)
  }

  @Test func `Discards source location`() throws {
    var test = fixture
    test.id = try testID("Module.FooTests/testFunc()/FooTests.swift:1:10")

    let (_, components, _) = try #require(test.decodeIDComponents())
    #expect(components == ["FooTests"])
  }

  @Test(arguments: [
    ("Module.`Foo Tests`/`test foo`()/FooTests.swift:1:10", ["`Foo Tests`"], "`test foo`()"),
    (
      "Module.`foo.swift:1:1`/`test foo.swift:1:1`()/FooTests.swift:1:10",
      ["`foo.swift:1:1`"], "`test foo.swift:1:1`()"
    ),
  ]) func `Handles raw identifiers`(
    id: String, components: [Substring], function: Substring
  ) throws {
    var test = fixture
    test.id = try testID(id)

    let actual = try #require(test.decodeIDComponents())
    #expect(actual == ("Module", components, .some(function)))
  }

  @Test(arguments: [
    ("Module.ImNot.AModule/Foo", ["ImNot.AModule", "Foo"]),  // Dotted components are allowed
    ("Module.", [""]),  // Module specified with empty components
  ]) func `Weird but supported formats`(id: String, components: [Substring]) throws {
    var test = fixture
    test.kind = .suite
    test.id = try testID(id)

    let actual = try #require(test.decodeIDComponents())
    #expect(actual == ("Module", components, nil))
  }

  @Test(arguments: [
    "MyTests/Foo",  // Missing module
    "",  // Empty test ID
    "ModuleA",  // Module only
  ]) func `Fails to decode invalid formats`(invalidTestID: String) throws {
    var test = fixture
    test.kind = .suite
    test.id = try testID(invalidTestID)

    #expect(test.decodeIDComponents() == nil)
  }
}
