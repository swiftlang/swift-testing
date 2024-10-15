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

#if !SWT_NO_EXIT_TESTS
@Suite("Exit test tests") struct ExitTestTests {
  @Test("Exit tests (passing)") func passing() async {
    await #expect(exitsWith: .failure) {
      exit(EXIT_FAILURE)
    }
    if EXIT_SUCCESS != EXIT_FAILURE + 1 {
      await #expect(exitsWith: .failure) {
        exit(EXIT_FAILURE + 1)
      }
    }
    await #expect(exitsWith: .success) {
      exit(EXIT_SUCCESS)
    }
    await #expect(exitsWith: .exitCode(123)) {
      exit(123)
    }
    await #expect(exitsWith: .exitCode(123)) {
      await Task.yield()
      exit(123)
    }
#if !os(Windows)
    await #expect(exitsWith: .signal(SIGKILL)) {
      _ = kill(getpid(), SIGKILL)
      // Allow up to 1s for the signal to be delivered.
      try! await Task.sleep(nanoseconds: 1_000_000_000_000)
    }
    await #expect(exitsWith: .signal(SIGABRT)) {
      abort()
    }
#endif
#if !SWT_NO_UNSTRUCTURED_TASKS
#if false
    // Test the detached (no task-local configuration) path. Disabled because,
    // like other tests using Task.detached, it can interfere with other tests
    // running concurrently.
    #expect(Test.current != nil)
    await Task.detached {
      #expect(Test.current == nil)
      await #expect(exitsWith: .failure) {
        fatalError()
      }
    }.value
#endif
#endif
  }

  @Test("Exit tests (failing)") func failing() async {
    let expectedCount: Int
#if os(Windows)
    expectedCount = 6
#else
    expectedCount = 10
#endif
    await confirmation("Exit tests failed", expectedCount: expectedCount) { failed in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case .issueRecorded = event.kind {
          failed()
        }
      }
      configuration.exitTestHandler = ExitTest.handlerForEntryPoint()

      await runTest(for: FailingExitTests.self, configuration: configuration)
    }
  }

  @Test("Mock exit test handlers (passing)") func passingMockHandler() async {
    await confirmation("System issue recorded", expectedCount: 0) { issueRecorded in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case .issueRecorded = event.kind {
          issueRecorded()
        }
      }

      // Mock an exit test where the process exits successfully.
      configuration.exitTestHandler = { _ in
        return ExitTest.Result(exitCondition: .exitCode(EXIT_SUCCESS))
      }
      await Test {
        await #expect(exitsWith: .success) {}
      }.run(configuration: configuration)

      // Mock an exit test where the process exits with a generic failure.
      configuration.exitTestHandler = { _ in
        return ExitTest.Result(exitCondition: .failure)
      }
      await Test {
        await #expect(exitsWith: .failure) {}
      }.run(configuration: configuration)
      await Test {
        await #expect(exitsWith: .exitCode(EXIT_FAILURE)) {}
      }.run(configuration: configuration)
#if !os(Windows)
      await Test {
        await #expect(exitsWith: .signal(SIGABRT)) {}
      }.run(configuration: configuration)
#endif

      // Mock an exit test where the process exits with a particular error code.
      configuration.exitTestHandler = { _ in
        return ExitTest.Result(exitCondition: .exitCode(123))
      }
      await Test {
        await #expect(exitsWith: .failure) {}
      }.run(configuration: configuration)

#if !os(Windows)
      // Mock an exit test where the process exits with a signal.
      configuration.exitTestHandler = { _ in
        return ExitTest.Result(exitCondition: .signal(SIGABRT))
      }
      await Test {
        await #expect(exitsWith: .signal(SIGABRT)) {}
      }.run(configuration: configuration)
      await Test {
        await #expect(exitsWith: .failure) {}
      }.run(configuration: configuration)
#endif
    }
  }

  @Test("Mock exit test handlers (failing)") func failingMockHandlers() async {
    let expectedCount: Int
#if os(Windows)
    expectedCount = 2
#else
    expectedCount = 6
#endif
    await confirmation("Issue recorded", expectedCount: expectedCount) { issueRecorded in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case .issueRecorded = event.kind {
          issueRecorded()
        }
      }

      // Mock exit tests that were expected to fail but passed.
      configuration.exitTestHandler = { _ in
        return ExitTest.Result(exitCondition: .exitCode(EXIT_SUCCESS))
      }
      await Test {
        await #expect(exitsWith: .failure) {}
      }.run(configuration: configuration)
      await Test {
        await #expect(exitsWith: .exitCode(EXIT_FAILURE)) {}
      }.run(configuration: configuration)
#if !os(Windows)
      await Test {
        await #expect(exitsWith: .signal(SIGABRT)) {}
      }.run(configuration: configuration)
#endif

#if !os(Windows)
      // Mock exit tests that unexpectedly signalled.
      configuration.exitTestHandler = { _ in
        return ExitTest.Result(exitCondition: .signal(SIGABRT))
      }
      await Test {
        await #expect(exitsWith: .exitCode(EXIT_SUCCESS)) {}
      }.run(configuration: configuration)
      await Test {
        await #expect(exitsWith: .exitCode(EXIT_FAILURE)) {}
      }.run(configuration: configuration)
      await Test {
        await #expect(exitsWith: .success) {}
      }.run(configuration: configuration)
#endif
    }
  }

  @Test("Exit test without configured exit test handler") func noHandler() async {
    await confirmation("System issue recorded") { issueRecorded in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case let .issueRecorded(issue) = event.kind, case .system = issue.kind {
          issueRecorded()
        }
      }

      await Test {
        await #expect(exitsWith: .success) {}
      }.run(configuration: configuration)
    }
  }

  @Test("Exit test forwards issues") func forwardsIssues() async {
    await confirmation("Issue recorded") { issueRecorded in
      await confirmation("Error caught") { errorCaught in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          guard case let .issueRecorded(issue) = event.kind else {
            return
          }
          if case .unconditional = issue.kind, issue.comments.contains("Something went wrong!") {
            issueRecorded()
          } else if issue.error != nil {
            errorCaught()
          }
        }
        configuration.exitTestHandler = ExitTest.handlerForEntryPoint()

        await Test {
          await #expect(exitsWith: .success) {
            #expect(Bool(false), "Something went wrong!")
            exit(0)
          }
          await #expect(exitsWith: .failure) {
            Issue.record(MyError())
          }
        }.run(configuration: configuration)
      }
    }
  }

#if !os(Linux)
  @Test("Exit test reports > 8 bits of the exit code")
  func fullWidthExitCode() async {
    // On POSIX-like platforms, we use waitid() which per POSIX should report
    // the full exit code, not just the low 8 bits. This behaviour is not
    // well-documented and not all platforms (as of this writing) report the
    // full value:
    //
    // | Platform             |  Bits Reported |
    // |----------------------|----------------|
    // | Darwin               |             32 |
    // | Linux                |              8 |
    // | Windows              | 32 (see below) |
    // | FreeBSD              |             32 |
    //
    // Other platforms may also have issues reporting the full value. This test
    // serves as a canary when adding new platforms that we need to document the
    // difference.
    //
    // Windows does not have the 8-bit exit code restriction and always reports
    // the full CInt value back to the testing library.
    await #expect(exitsWith: .exitCode(512)) {
      exit(512)
    }
  }
#endif

  @Test("Exit condition matching operators (==, !=, ===, !==)")
  func exitConditionMatching() {
    #expect(ExitCondition.success == .success)
    #expect(ExitCondition.success === .success)
    #expect(ExitCondition.success == .exitCode(EXIT_SUCCESS))
    #expect(ExitCondition.success === .exitCode(EXIT_SUCCESS))
    #expect(ExitCondition.success != .exitCode(EXIT_FAILURE))
    #expect(ExitCondition.success !== .exitCode(EXIT_FAILURE))

    #expect(ExitCondition.failure == .failure)
    #expect(ExitCondition.failure === .failure)

    #expect(ExitCondition.exitCode(EXIT_FAILURE &+ 1) != .exitCode(EXIT_FAILURE))
    #expect(ExitCondition.exitCode(EXIT_FAILURE &+ 1) !== .exitCode(EXIT_FAILURE))

#if !os(Windows)
    #expect(ExitCondition.success != .exitCode(EXIT_FAILURE))
    #expect(ExitCondition.success !== .exitCode(EXIT_FAILURE))
    #expect(ExitCondition.success != .signal(SIGINT))
    #expect(ExitCondition.success !== .signal(SIGINT))
    #expect(ExitCondition.signal(SIGINT) == .signal(SIGINT))
    #expect(ExitCondition.signal(SIGINT) === .signal(SIGINT))
    #expect(ExitCondition.signal(SIGTERM) != .signal(SIGINT))
    #expect(ExitCondition.signal(SIGTERM) !== .signal(SIGINT))
#endif
  }

  @MainActor static func someMainActorFunction() {
    MainActor.assertIsolated()
  }

  @Test("Exit test can be main-actor-isolated")
  @MainActor
  func mainActorIsolation() async {
    await #expect(exitsWith: .success) {
      await Self.someMainActorFunction()
      _ = 0
      exit(EXIT_SUCCESS)
    }
  }

  @Test("Result is set correctly (success)")
  func exitTestResultOnSuccess() async throws {
    // Test that basic passing exit tests produce the correct results (#expect)
    var result = await #expect(exitsWith: .success) {
      exit(EXIT_SUCCESS)
    }
    #expect(result.exitCondition === .success)
    result = await #expect(exitsWith: .exitCode(123)) {
      exit(123)
    }
    #expect(result.exitCondition === .exitCode(123))

    // Test that basic passing exit tests produce the correct results (#require)
    result = try await #require(exitsWith: .success) {
      exit(EXIT_SUCCESS)
    }
    #expect(result.exitCondition === .success)
    result = try await #require(exitsWith: .exitCode(123)) {
      exit(123)
    }
    #expect(result.exitCondition === .exitCode(123))
  }

  @Test("Result is set correctly (failure)")
  func exitTestResultOnFailure() async {
    // Test that an exit test that produces the wrong exit condition reports it
    // as an expectation failure, but also returns the exit condition (#expect)
    await confirmation("Expectation failed") { expectationFailed in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case let .issueRecorded(issue) = event.kind {
          if case .expectationFailed = issue.kind {
            expectationFailed()
          } else {
            issue.record()
          }
        }
      }
      configuration.exitTestHandler = { _ in
        ExitTest.Result(exitCondition: .exitCode(123))
      }

      await Test {
        let result = await #expect(exitsWith: .success) {}
        #expect(result.exitCondition === .exitCode(123))
      }.run(configuration: configuration)
    }

    // Test that an exit test that produces the wrong exit condition throws an
    // ExpectationFailedError (#require)
    await confirmation("Expectation failed") { expectationFailed in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case let .issueRecorded(issue) = event.kind {
          if case .expectationFailed = issue.kind {
            expectationFailed()
          } else {
            issue.record()
          }
        }
      }
      configuration.exitTestHandler = { _ in
        ExitTest.Result(exitCondition: .failure)
      }

      await Test {
        try await #require(exitsWith: .success) {}
        fatalError("Unreachable")
      }.run(configuration: configuration)
    }
  }

  @Test("Result is set correctly (system failure)")
  func exitTestResultOnSystemFailure() async {
    // Test that an exit test that fails to start due to a system error produces
    // a .system issue and reports .failure as its exit condition.
    await confirmation("System issue recorded") { systemIssueRecorded in
      await confirmation("Expectation failed") { expectationFailed in
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case let .issueRecorded(issue) = event.kind {
            if case .system = issue.kind {
              systemIssueRecorded()
            } else if case .expectationFailed = issue.kind {
              expectationFailed()
            } else {
              issue.record()
            }
          }
        }
        configuration.exitTestHandler = { _ in
          throw MyError()
        }

        await Test {
          let result = await #expect(exitsWith: .success) {}
          #expect(result.exitCondition === .failure)
        }.run(configuration: configuration)
      }
    }
  }
}

// MARK: - Fixtures

@Suite(.hidden) struct FailingExitTests {
  @Test(.hidden) func failingExitTests() async {
    await #expect(exitsWith: .success) {}
    await #expect(exitsWith: .failure) {}
    await #expect(exitsWith: .exitCode(123)) {}
    await #expect(exitsWith: .failure) {
      exit(EXIT_SUCCESS)
    }
    await #expect(exitsWith: .success) {
      exit(EXIT_FAILURE)
    }
    await #expect(exitsWith: .exitCode(123)) {
      exit(0)
    }

#if !os(Windows)
    await #expect(exitsWith: .exitCode(SIGABRT)) {
      // abort() raises on Windows, but we don't handle that yet and it is
      // reported as .failure (which will fuzzy-match with SIGABRT.)
      abort()
    }
    await #expect(exitsWith: .signal(123)) {}
    await #expect(exitsWith: .signal(123)) {
      exit(123)
    }
    await #expect(exitsWith: .signal(SIGSEGV)) {
      abort() // sends SIGABRT, not SIGSEGV
    }
#endif
  }
}

#if false // intentionally fails to compile
@Test(arguments: 100 ..< 200)
func sellIceCreamCones(count: Int) async throws {
  try await #require(exitsWith: .failure) {
    precondition(count < 10, "Too many ice cream cones")
  }
}
#endif
#endif
