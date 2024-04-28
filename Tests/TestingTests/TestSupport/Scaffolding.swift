//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_XCTEST_SCAFFOLDING && !SWIFT_PM_SUPPORTS_SWIFT_TESTING && canImport(XCTest)
import XCTest
import Testing

final class AllTests: XCTestCase {
  func testAll() async {
    await XCTestScaffold.runAllTests(hostedBy: self)
  }
}
#endif
