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

@Suite("TestingError Tests")
struct TestingErrorTests {
  @Test("TestingError.description property (.errno)", arguments: 1 ..< 100)
  func errnoDescription(errorCode: CInt) {
    let description = String(describing: TestingError.errno(errorCode))
    #expect(!description.isEmpty)
    #expect(strerror(errorCode) == description)
  }

#if os(Windows)
  @Test("TestingError.description property (.win32)",
    arguments: [
      (ERROR_OUTOFMEMORY, "Not enough memory resources are available to complete this operation."),
      (ERROR_INVALID_ACCESS, "The access code is invalid."),
      (ERROR_ARITHMETIC_OVERFLOW, "Arithmetic result exceeded 32 bits."),
      (999_999_999, "An unknown error occurred (999999999)."),
    ]
  )
  fileprivate func win32Description(errorCode: CInt, expectedMessage: String) {
    let description = String(describing: TestingError.win32(DWORD(errorCode)))
    #expect(!description.isEmpty)
    #expect(expectedMessage == description)
  }
#endif

  @Test("TestingError.description property (.system)")
  fileprivate func systemDescription() {
    let description = String(describing: TestingError.system("Lorem ipsum"))
    #expect(!description.isEmpty)
    #expect("Lorem ipsum" == description)
  }
}
