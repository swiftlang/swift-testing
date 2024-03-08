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

@Suite("UncheckedSendable Tests")
struct UncheckedSendableTests {
  @Test("Value is read/written correctly")
  func value() {
    let randomNumber = Int.random(in: 0 ... .max)
    var value = UncheckedSendable(rawValue: randomNumber)
    #expect(randomNumber == value.rawValue)
    value.rawValue += 1
    #expect(randomNumber != value.rawValue)
  }

  @Test("UncheckedSendable.description property")
  func description() {
    let randomNumber = Int.random(in: 0 ... .max)
    let value = UncheckedSendable(rawValue: randomNumber)
    #expect(String(describing: randomNumber) == String(describing: value))
  }

  @Test("UncheckedSendable.debugDescription property")
  func debugDescription() {
    // Use Optional<Int> because it conforms to CustomDebugStringConvertible
    let randomNumber: Int? = Int.random(in: 0 ... .max)
    let value = UncheckedSendable(rawValue: randomNumber)
    #expect(String(reflecting: randomNumber) == String(reflecting: value))
  }
}
