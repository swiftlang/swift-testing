//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ForToolsIntegrationOnly) import Testing

@Suite("Runner.RuntimeState Tests")
struct Runner_RuntimeStateTests {
  // This confirms that the `eventHandler` of a nested runner's configuration
  // has the runtime state of the "outer" runner, so that task local data is
  // handled appropriately.
  @Test func runnerStateScopedEventHandler() async {
    var configuration = Configuration()
    configuration.eventHandler = { _, _ in
      // Inside this event handler, the current Test should be the outer `@Test`
      // function, not the temporary `Test` created below.
      #expect(Test.current?.name == "runnerStateScopedEventHandler()")
    }

    await Test(name: "foo") {}.run(configuration: configuration)
  }

  // This confirms that an event posted within the closure of `withTaskGroup`
  // (and similar APIs) in regular tests (those which are not testing the
  // testing library itself) are handled appropriately and do not crash.
  @Test func eventPostingInTaskGroup() async {
    // Enable delivery of "expectation checked" events, merely as a way to allow
    // an event to be posted during the test below without causing any real
    // issues to be recorded or otherwise confuse the testing harness.
    var configuration = Configuration.current ?? .init()
    configuration.deliverExpectationCheckedEvents = true

    await Configuration.withCurrent(configuration) {
      await withTaskGroup(of: Void.self) { group in
        #expect(Bool(true))
      }
    }
  }
}
