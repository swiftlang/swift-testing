//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import Testing
private import TestingInternals

@Suite("CError Tests")
struct CErrorTests {
  @Test("CError.description property", arguments: 1 ..< 100)
  func errorDescription(errorCode: CInt) {
    let description = String(describing: CError(rawValue: errorCode))
    #expect(!description.isEmpty)
    #expect(strerror(errorCode) == description)
  }
}
