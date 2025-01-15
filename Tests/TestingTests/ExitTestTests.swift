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
    await #expect(exitsWith: .success) {}
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
    await #expect(exitsWith: .signal(SIGSEGV)) {
      _ = raise(SIGSEGV)
      // Allow up to 1s for the signal to be delivered. On some platforms,
      // raise() delivers signals fully asynchronously and may not terminate the
      // child process before this closure returns.
      if #available(_clockAPI, *) {
        try await Test.Clock.sleep(for: .seconds(1))
      } else {
        try await Task.sleep(nanoseconds: 1_000_000_000)
      }
    }
    await #expect(exitsWith: .signal(SIGABRT)) {
      abort()
    }
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
    await confirmation("Exit tests failed", expectedCount: 9) { failed in
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
        return ExitTestArtifacts(exitCondition: .exitCode(EXIT_SUCCESS))
      }
      await Test {
        await #expect(exitsWith: .success) {}
      }.run(configuration: configuration)

      // Mock an exit test where the process exits with a generic failure.
      configuration.exitTestHandler = { _ in
        return ExitTestArtifacts(exitCondition: .failure)
      }
      await Test {
        await #expect(exitsWith: .failure) {}
      }.run(configuration: configuration)
      await Test {
        await #expect(exitsWith: .exitCode(EXIT_FAILURE)) {}
      }.run(configuration: configuration)
      await Test {
        await #expect(exitsWith: .signal(SIGABRT)) {}
      }.run(configuration: configuration)

      // Mock an exit test where the process exits with a particular error code.
      configuration.exitTestHandler = { _ in
        return ExitTestArtifacts(exitCondition: .exitCode(123))
      }
      await Test {
        await #expect(exitsWith: .failure) {}
      }.run(configuration: configuration)

      // Mock an exit test where the process exits with a signal.
      configuration.exitTestHandler = { _ in
        return ExitTestArtifacts(exitCondition: .signal(SIGABRT))
      }
      await Test {
        await #expect(exitsWith: .signal(SIGABRT)) {}
      }.run(configuration: configuration)
      await Test {
        await #expect(exitsWith: .failure) {}
      }.run(configuration: configuration)
    }
  }

  @Test("Mock exit test handlers (failing)") func failingMockHandlers() async {
    await confirmation("Issue recorded", expectedCount: 6) { issueRecorded in
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case .issueRecorded = event.kind {
          issueRecorded()
        }
      }

      // Mock exit tests that were expected to fail but passed.
      configuration.exitTestHandler = { _ in
        return ExitTestArtifacts(exitCondition: .exitCode(EXIT_SUCCESS))
      }
      await Test {
        await #expect(exitsWith: .failure) {}
      }.run(configuration: configuration)
      await Test {
        await #expect(exitsWith: .exitCode(EXIT_FAILURE)) {}
      }.run(configuration: configuration)
      await Test {
        await #expect(exitsWith: .signal(SIGABRT)) {}
      }.run(configuration: configuration)

      // Mock exit tests that unexpectedly signalled.
      configuration.exitTestHandler = { _ in
        return ExitTestArtifacts(exitCondition: .signal(SIGABRT))
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
    #expect(Optional<ExitCondition>.none == Optional<ExitCondition>.none)
    #expect(Optional<ExitCondition>.none === Optional<ExitCondition>.none)
    #expect(Optional<ExitCondition>.none !== .some(.success))
    #expect(Optional<ExitCondition>.none !== .some(.failure))

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

    #expect(ExitCondition.success != .exitCode(EXIT_FAILURE))
    #expect(ExitCondition.success !== .exitCode(EXIT_FAILURE))
    #expect(ExitCondition.success != .signal(SIGINT))
    #expect(ExitCondition.success !== .signal(SIGINT))
    #expect(ExitCondition.signal(SIGINT) == .signal(SIGINT))
    #expect(ExitCondition.signal(SIGINT) === .signal(SIGINT))
    #expect(ExitCondition.signal(SIGTERM) != .signal(SIGINT))
    #expect(ExitCondition.signal(SIGTERM) !== .signal(SIGINT))
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

  @Test("Result is set correctly on success")
  func successfulArtifacts() async throws {
    // Test that basic passing exit tests produce the correct results (#expect)
    var result = await #expect(exitsWith: .success) {
      exit(EXIT_SUCCESS)
    }
    #expect(result?.exitCondition === .success)
    result = await #expect(exitsWith: .exitCode(123)) {
      exit(123)
    }
    #expect(result?.exitCondition === .exitCode(123))

    // Test that basic passing exit tests produce the correct results (#require)
    result = try await #require(exitsWith: .success) {
      exit(EXIT_SUCCESS)
    }
    #expect(result?.exitCondition === .success)
    result = try await #require(exitsWith: .exitCode(123)) {
      exit(123)
    }
    #expect(result?.exitCondition === .exitCode(123))
  }

  @Test("Result is nil on failure")
  func nilArtifactsOnFailure() async {
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
        ExitTestArtifacts(exitCondition: .exitCode(123))
      }

      await Test {
        let result = await #expect(exitsWith: .success) {}
        #expect(result == nil)
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
        ExitTestArtifacts(exitCondition: .failure)
      }

      await Test {
        try await #require(exitsWith: .success) {}
        fatalError("Unreachable")
      }.run(configuration: configuration)
    }
  }

  @Test("Result is nil on system failure")
  func nilArtifactsOnSystemFailure() async {
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
          #expect(result == nil)
        }.run(configuration: configuration)
      }
    }
  }

  @Test("Result contains stdout/stderr")
  func exitTestResultContainsStandardStreams() async throws {
    var result = try await #require(exitsWith: .success, observing: [\.standardOutputContent]) {
      try FileHandle.stdout.write("STANDARD OUTPUT")
      try FileHandle.stderr.write(String("STANDARD ERROR".reversed()))
      exit(EXIT_SUCCESS)
    }
    #expect(result.exitCondition === .success)
    #expect(result.standardOutputContent.contains("STANDARD OUTPUT".utf8))
    #expect(result.standardErrorContent.isEmpty)

    result = try await #require(exitsWith: .success, observing: [\.standardErrorContent]) {
      try FileHandle.stdout.write("STANDARD OUTPUT")
      try FileHandle.stderr.write(String("STANDARD ERROR".reversed()))
      exit(EXIT_SUCCESS)
    }
    #expect(result.exitCondition === .success)
    #expect(result.standardOutputContent.isEmpty)
    #expect(result.standardErrorContent.contains("STANDARD ERROR".utf8.reversed()))
  }

  @Test("Arguments to the macro are not captured during expansion (do not need to be literals/const)")
  func argumentsAreNotCapturedDuringMacroExpansion() async throws {
    let unrelatedSourceLocation = #_sourceLocation
    func nonConstExitCondition() async throws -> ExitCondition {
      .failure
    }
    await #expect(exitsWith: try await nonConstExitCondition(), sourceLocation: unrelatedSourceLocation) {
      fatalError()
    }
  }
}

// MARK: - Fixtures

@Suite(.hidden) struct FailingExitTests {
  @Test(.hidden) func failingExitTests() async {
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
  }
}

#if false // intentionally fails to compile
@Test(.hidden, arguments: 100 ..< 200)
func sellIceCreamCones(count: Int) async throws {
  try await #require(exitsWith: .failure) {
    precondition(count < 10, "Too many ice cream cones")
  }
}
#endif
#endif
