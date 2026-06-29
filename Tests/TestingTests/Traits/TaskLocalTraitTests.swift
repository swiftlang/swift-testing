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

@Suite("Task Local Tests", .tags(.traitRelated))
struct TaskLocalTests {
  @Test(
    ".taskLocal trait",
    .taskLocal($dummyLocal, true)
  )
  func taskLocalBinding() throws {
    #expect(dummyLocal == true)
  }
}
