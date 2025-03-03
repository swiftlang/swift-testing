//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

private import _TestingInternals

@Suite("CustomTestStringConvertible Tests")
struct CustomTestStringConvertibleTests {
  @Test func optionals() {
    #expect(String(describingForTest: 0 as Int?) == "0")
    #expect(String(describingForTest: "abc" as String?) == #""abc""#)
    #expect(String(describingForTest: nil as Int?) == "nil")
    #expect(String(describingForTest: nil as String?) == "nil")
    #expect(String(describingForTest: nil as _OptionalNilComparisonType) == "nil")
  }

  @Test func strings() {
    #expect(String(describingForTest: "abc") == #""abc""#)
    #expect(String(describingForTest: "abc"[...] as Substring) == #""abc""#)
  }

  @Test func ranges() {
    #expect(String(describingForTest: 0 ... 1) == "0 ... 1")
    #expect(String(describingForTest: 0...) == "0...")
    #expect(String(describingForTest: ...1) == "...1")
    #expect(String(describingForTest: ..<1) == "..<1")
    #expect(String(describingForTest: 0 ..< 1) == "0 ..< 1")
  }

  @Test func types() {
    #expect(String(describingForTest: Self.self) == "CustomTestStringConvertibleTests")
    #expect(String(describingForTest: NonCopyableType.self) == "NonCopyableType")
  }

  @Test func enumerations() {
    #expect(String(describingForTest: SWTTestEnumeration.A) == "SWTTestEnumeration(rawValue: \(SWTTestEnumeration.A.rawValue))")
    #expect(String(describingForTest: SomeEnum.elitSedDoEiusmod) == ".elitSedDoEiusmod")
  }

  @Test func otherProtocols() {
    #expect(String(describingForTest: CustomStringConvertibleType()) == "Lorem ipsum")
    #expect(String(describingForTest: TextOutputStreamableType()) == "Dolor sit amet")
    #expect(String(describingForTest: CustomDebugStringConvertibleType()) == "Consectetur adipiscing")
  }
}

// MARK: - Fixtures

private struct NonCopyableType: ~Copyable {}

private struct CustomStringConvertibleType: CustomStringConvertible {
  var description: String {
    "Lorem ipsum"
  }
}

private struct TextOutputStreamableType: TextOutputStreamable {
  func write(to target: inout some TextOutputStream) {
    target.write("Dolor sit amet")
  }
}

private struct CustomDebugStringConvertibleType: CustomDebugStringConvertible {
  var debugDescription: String {
    "Consectetur adipiscing"
  }
}

private enum SomeEnum {
  case elitSedDoEiusmod
}
