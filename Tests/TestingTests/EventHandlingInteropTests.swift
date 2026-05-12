//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ForToolsIntegrationOnly) import Testing
private import _TestingInternals

#if !SWT_TARGET_OS_APPLE && canImport(Synchronization)
import Synchronization
#endif

#if SWT_TARGET_OS_APPLE
// Xcode already installs a handler, so the preconditions for this suite may not be met
let interopHandlerMayBeInstalled = Environment.variable(named: "XCTestSessionIdentifier") != nil
#else
let interopHandlerMayBeInstalled = false
#endif

#if !SWT_NO_EXIT_TESTS && !SWT_NO_INTEROP
@Suite(.disabled(if: interopHandlerMayBeInstalled))
struct EventHandlingInteropTests {
  static let handlerContents = Mutex<(version: String, record: String?)?>()

  private static let capturingHandler: SWTFallbackEventHandler = {
    schemaVersion, recordJSONBaseAddress, recordJSONByteCount, _ in
    let version = String(cString: schemaVersion)
    let recordJSON = UnsafeRawBufferPointer(start: recordJSONBaseAddress, count: recordJSONByteCount)
    let record = String(decoding: recordJSON, as: UTF8.self)
    Self.handlerContents.withLock {
      $0 = (version: version, record: record)
    }
  }

  /// Sets the env var that enables the experimental interop feature.
  /// Must be set before we call `Event.installFallbackEventHandler()` which
  /// will cache the install outcome.
  static func enableExperimentalInterop() {
    Environment.setVariable("1", named: Interop.experimentalOptInKey)
  }

  /// Sets the env var that determines the interop mode.
  /// Must be set before we call `Event.installFallbackEventHandler()` which
  /// will cache the install outcome.
  static func setInteropMode(_ mode: Interop.Mode) {
    Environment.setVariable(mode.rawValue, named: Interop.Mode.interopModeEnvKey)
  }

  /// This uses an exit test to run in a clean process, ensuring that the
  /// installed fallback event handler does not affect other tests.
  ///
  /// Note this test will no longer work once Swift Testing starts installing
  /// its own fallback handler.
  @Test func `Post event without config -> fallback handler`() async throws {
    await #expect(processExitsWith: .success) {
      Configuration.removeAll()
      try #require(
        _swift_testing_installFallbackEventHandler(Self.capturingHandler),
        "Installation of fallback handler should succeed")

      // The detached task forces the event to be posted when Configuration.current
      // is nil and triggers the post to fallback handler path
      await Task.detached {
        Event.post(.issueRecorded(Issue(kind: .system)), configuration: nil)
      }.value

      // Assert that the expectation failure contents were sent to the fallback event handler
      try Self.handlerContents.withLock {
        let contents = try #require(
          $0, "Fallback should have been called with non nil contents")
        let versionNumberString = "\(ABI.v6_3.versionNumber)"
        #expect(contents.version == versionNumberString)
        #expect(contents.record?.contains(versionNumberString) == true)
        #expect(contents.record?.contains("A system failure occurred") == true)
      }
    }
  }

  @Test func `Enabling experimental interop lets you install the handler`() async {
    await #expect(processExitsWith: .success) {
      // Experimental interop not set
      let ok = Event.installFallbackEventHandler()

      #expect(!ok, "Should fail because experimental interop not enabled")
    }

    await #expect(processExitsWith: .success) {
      Self.enableExperimentalInterop()
      let ok = Event.installFallbackEventHandler()

      #expect(ok, "Should succeed because experimental interop is enabled")
    }
  }

  @Test func `Running tests installs the fallback handler`() async {
    await #expect(processExitsWith: .success) {
      Self.enableExperimentalInterop()
      let handlerBefore = _swift_testing_getFallbackEventHandler()

      await Test {}.run()

      let handlerAfter = _swift_testing_getFallbackEventHandler()

      #expect(handlerBefore == nil, "There should be no handler before running the test")
      #expect(handlerAfter != nil, "There should be a handler after running the test")
    }
  }

  private static let unusableHandler: SWTFallbackEventHandler = { _, _, _, _ in
    fatalError("The fallback event handler should NOT have been called!")
  }

  /// Regression testing for a bug where we incorrectly directed issues to
  /// fallback event path for issues recorded without an associated configuration
  @Test(.bug("rdar://170161483"), .filterIssues { !$0.description.contains("[FILTER OUT]") })
  func `Recording issue in detached task doesn't forward to fallback event handler`() async {
    await #expect(processExitsWith: .success) {
      // Install a handler that shouldn't ever get called.
      try #require(
        _swift_testing_installFallbackEventHandler(Self.unusableHandler),
        "Installation of fallback handler should succeed")

      // Record an issue in a detached task, which should be forwarded to Configuration.all
      // and NOT the installed fallback event handler.
      _ = await Task.detached {
        Issue.record("[FILTER OUT] This issue was recorded in a detached task", severity: .warning)
      }.value

      // If this recurses infinitely, the process will likely exhaust the stack space and crash here.
    }
  }

  @Test func `Sending fallback event to ourselves doesn't cause infinite loop`() async {
    await #expect(processExitsWith: .success) {
      Self.enableExperimentalInterop()
      try #require(Event.installFallbackEventHandler(), "Should successfully install a handler")

      // Force the event to be handled by the fallback event handler
      Configuration.removeAll()
      try await Task.detached {
        try #require(
          Configuration.current == nil,
          "There should be no current config so that we trigger the fallback path")
        Event.post(.issueRecorded(Issue(kind: .system)), configuration: nil)
      }.value

      // If this recurses infinitely, the process will likely exhaust the stack space and crash here.
    }
  }

  // MARK: - End to end handling of an issue with interop

  @Test func `Fallback handler records an issue if invalid event provided`() async throws {
    await #expect(processExitsWith: .success) {
      Self.enableExperimentalInterop()

      // Pass an invalid record JSON to the event handler
      let issues = await Test {
        let emptyJSON = Array("{}".utf8)
        try _FakeXCTFail(payload: emptyJSON)
      }.runCapturingIssues()

      // Assert that we record an issue with a helpful debug message
      let expectedPrefix =
        "A system failure occurred (error): Another test library reported a test event that Swift Testing could not decode. Inspect the payload to determine if this was a test assertion failure."
      let actualMessages = issues.map { $0.description }
      #expect(actualMessages.count == 1)
      #expect(
        actualMessages.first?.hasPrefix(expectedPrefix) == true,
        "\(actualMessages) did not match the expected message")
    }
  }

  @Test func `Fallback handler not installed if interop mode set to none`() async {
    await #expect(processExitsWith: .success) {
      // Enable the interop feature but explicitly turn off the interop mode
      Self.enableExperimentalInterop()
      Self.setInteropMode(.none)

      // Running the test would normally lead to the handler being installed
      await Test {}.run()

      let currentHandler = _swift_testing_getFallbackEventHandler()
      #expect(
        currentHandler == nil,
        "Fallback event handler should not be installed if interop mode is none"
      )
    }
  }

  @Test func `Limited interop mode uses warning severity`() async throws {
    await #expect(processExitsWith: .success) {
      Self.enableExperimentalInterop()
      Self.setInteropMode(.limited)
      try #require(Event.installFallbackEventHandler())

      // Run the test, which should record two issues in response to the interop one
      let issues = await Test {
        try _FakeXCTFail()
      }.runCapturingIssues()

      // Generate the interop test failure (as a warning) and warning about XCTest API usage
      #expect(
        issues.map { $0.severity } == [.warning, .warning]
      )
    }
  }

  @Test func `Complete interop mode uses error severity`() async throws {
    await #expect(processExitsWith: .success) {
      Self.enableExperimentalInterop()
      Self.setInteropMode(.complete)
      try #require(Event.installFallbackEventHandler())

      // Run the test, which should record two issues in response to the interop one
      let issues = await Test {
        try _FakeXCTFail()
      }.runCapturingIssues()

      // Generate the interop test failure and warning about XCTest API usage
      #expect(
        issues.map { $0.severity }.sorted() == [.warning, .error]
      )
    }
  }

  @available(macOS 15.0, *)  // String(validating:as:) is unavailable on older macOS
  @Test func `Strict interop mode causes a process exit`() async throws {
    let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
      Self.enableExperimentalInterop()
      Self.setInteropMode(.strict)
      try #require(Event.installFallbackEventHandler())

      // Run the test, which should cause a process exit due to strict mode
      await Test {
        try _FakeXCTFail()
      }.run()
    }

    let stderr = try #require(
      String(validating: result?.standardErrorContent ?? [UInt8](), as: UTF8.self))
    #expect(stderr.contains("Fatal error: XCTest API was used in a Swift Testing test"))
  }

  @Test func `Handle fallback event warns issue about XCTest API usage`() async throws {
    await #expect(processExitsWith: .success) {
      Self.enableExperimentalInterop()
      try #require(Event.installFallbackEventHandler())

      // Run the test, which should record two issues in response to the interop one
      // Prepare a test issue to inject into that handler to simulate receiving an interop issue.
      let issues = await Test {
        try _FakeXCTFail()
      }.runCapturingIssues()

      #expect(
        issues.map { $0.description }.sorted() == [
          "An API was misused (warning): XCTest API was used in a Swift Testing test. Adopt Swift Testing primitives, such as #expect, instead.",
          "Issue recorded (warning)",
        ]
      )
    }
  }

  // MARK: - Preserve issue severity = warning across interop boundary

  /// Interop mode normally turns test issues into errors.
  /// However, we don't want to clobber anything naturally reported as a warning.
  @Test func `Interop send: warning issue stays as warning`() async throws {
    await #expect(processExitsWith: .success) {
      Configuration.removeAll()
      Self.setInteropMode(.complete)
      try #require(
        _swift_testing_installFallbackEventHandler(Self.capturingHandler),
        "Installation of fallback handler should succeed")

      await Task.detached {
        Event.post(.issueRecorded(Issue(kind: .system, severity: .warning)), configuration: nil)
      }.value

      // Assert that the issue stays as a warning
      try Self.handlerContents.withLock {
        let contents = try #require(
          $0, "Fallback should have been called with non nil contents")
        let recordData = try #require(contents.record.map(\.utf8).map(Array.init))
        let record = try recordData.withUnsafeBytes { recordData in
          try JSON.decode(ABI.Record<ABI.v6_3>.self, from: recordData)
        }
        guard case .event(let event) = record.kind else {
          Issue.record("Wrong type of record: \(record)")
          return
        }

        #expect(event.issue?.severity == .warning)
      }
    }
  }

  /// Interop mode normally turns test issues into errors.
  /// However, we don't want to clobber anything naturally reported as a warning.
  @Test func `Interop receive: warning issue stays as warning`() async throws {
    await #expect(processExitsWith: .success) {
      Self.enableExperimentalInterop()
      Self.setInteropMode(.complete)
      try #require(Event.installFallbackEventHandler())

      // Run the test, which should record two issues in response to the interop one
      let issues = await Test {
        try _FakeXCTFail(severity: .warning)
      }.runCapturingIssues()

      #expect(issues.map(\.severity) == [.warning, .warning])
      #expect(issues.map(\.description).sorted() == [
          "An API was misused (warning): XCTest API was used in a Swift Testing test. Adopt Swift Testing primitives, such as #expect, instead.",
          "Issue recorded (warning)"
        ]
      )
    }
  }
}

/// Simulates the behaviour of XCTFail when called in a Swift Testing test.
/// This always forwards a test failure through the fallback event handler if it can find one.
/// It is an error to call this when a handler hasn't been installed yet.
/// - Parameter payload: Optional payload to use instead of generating a standard one.
private func _FakeXCTFail(payload: [UInt8]? = nil, severity: Issue.Severity = .error) throws {
  // A fallback event handler must be installed ahead of time
  let currentHandler = try #require(_swift_testing_getFallbackEventHandler())

  func wrapInEncodedEvent(issue: Issue) throws -> [UInt8] {
    let event = Event(.issueRecorded(issue), testID: nil, testCaseID: nil, instant: .now)
    let encodedEvent = ABI.Record<ABI.CurrentVersion>(
      encoding: event, in: .init(test: nil, testCase: nil, iteration: nil, configuration: nil),
      messages: [])
    return try JSON.withEncoding(of: encodedEvent) { Array($0) }
  }

  let encodedIssue = try payload ?? wrapInEncodedEvent(issue: .init(kind: .unconditional, severity: severity))

  encodedIssue.withUnsafeBytes { ptr in
    let vers = String(describing: ABI.CurrentVersion.versionNumber)
    currentHandler(vers, ptr.baseAddress!, ptr.count, nil)
  }
}
#endif
