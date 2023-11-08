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
import TestingInternals

@Suite("CError Tests")
struct CErrorTests {
  @Test("CError.description property", arguments: 1 ..< 100)
  func errorDescription(errorCode: CInt) {
    // The set of error codes actually defined by standard C is quite narrow.
    // EDOM is one of the few defined codes.
    let description = String(describing: CError(rawValue: errorCode))
    #expect(!description.isEmpty)
    description.withCString { description in
      #expect(0 == strcmp(strerror(errorCode), description))
    }
  }
}
