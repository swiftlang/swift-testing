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

@Suite(.tags(.traitRelated))
struct `TaskLocalTrait tests` {
  @Test(.taskLocal(local, withValue: true))
  func `.taskLocal trait`() throws {
    #expect(local.wrappedValue == true)
  }

  @Suite(.serialized, .taskLocal(stateLocal, withValue: State()))
  struct `Mutable task local values` {
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

  @Test func `evaluate()`() async throws {
    let trait = TaskLocalTrait.taskLocal(stateLocal, withValue: State(count: 99))
    let state = try await trait.evaluate()
    #expect(state.count == 99)
  }
}

// MARK: - Fixtures

private let local = TaskLocal(wrappedValue: false)
private class State: @unchecked Sendable {
  var count: Int
  init(count: Int = 0) {
    self.count = count
  }
}
private let stateLocal = TaskLocal(wrappedValue: State())
