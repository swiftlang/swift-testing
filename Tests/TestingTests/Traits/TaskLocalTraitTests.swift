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
    .taskLocal(local, true)
  )
  func taskLocalBinding() throws {
    #expect(local.wrappedValue == true)
  }

  @Suite(.serialized, .taskLocal(stateLocal, State())) struct MutableLocal {
    @Test func run1() {
      #expect(stateLocal.wrappedValue.count == 0)
      stateLocal.wrappedValue.count += 1
      #expect(stateLocal.wrappedValue.count == 1)
    }
    @Test func run2() {
      #expect(stateLocal.wrappedValue.count == 0)
      stateLocal.wrappedValue.count += 1
      #expect(stateLocal.wrappedValue.count == 1)
    }
  }
}

private let local = TaskLocal(wrappedValue: false)
private class State: @unchecked Sendable {
  var count = 0
}
private let stateLocal = TaskLocal(wrappedValue: State())
