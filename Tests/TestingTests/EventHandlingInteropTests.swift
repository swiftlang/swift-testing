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

#if canImport(Foundation)
import Foundation
#endif
#if !SWT_TARGET_OS_APPLE && canImport(Synchronization)
import Synchronization
#endif

#if !SWIFT_PACKAGE && SWT_TARGET_OS_APPLE
// Xcode already installs a handler, so the preconditions for this suite may not be met
let interopHandlerMayBeInstalled = true
#else
let interopHandlerMayBeInstalled = false
#endif

#if !SWT_NO_EXIT_TESTS && compiler(>=6.3) && !SWT_NO_INTEROP && canImport(Foundation)
@Suite(.disabled(if: interopHandlerMayBeInstalled))
struct EventHandlingInteropTests {
  static let handlerContents = Mutex<(version: String, record: String?)?>()

  private static let capturingHandler: SWTFallbackEventHandler = {
    schemaVersion, recordJSONBaseAddress, recordJSONByteCount, _ in
    let version = String(cString: schemaVersion)
    let record = String(
      data: Data(bytes: recordJSONBaseAddress, count: recordJSONByteCount),
      encoding: .utf8)
    Self.handlerContents.withLock {
      $0 = (version: version, record: record)
    }
  }

  /// Sets the env var that enables the experimental interop feature. Must be
  /// set before we call `Event.installFallbackEventHandler()` which will cache
  /// the install outcome.
  static func enableExperimentalInterop() {
    Environment.setVariable("1", named: "SWT_EXPERIMENTAL_INTEROP_ENABLED")
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
        #expect(contents.version == "\(ABI.CurrentVersion.versionNumber)")
        #expect(contents.record?.contains("A system failure occurred") ?? false)
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

  @Test func `Handle fallback event warns issue about XCTest API usage`() async throws {
    await #expect(processExitsWith: .success) {
      // Install and retrieve the fallback event handler.
      // Prepare a test issue to inject into that handler to simulate receiving an interop issue.
      let eventJSON = try {
        let issue = Issue(kind: .unconditional)
        let event = Event(.issueRecorded(issue), testID: nil, testCaseID: nil, instant: .now)
        let encodedEvent = ABI.Record<ABI.CurrentVersion>(
          encoding: event, in: .init(test: nil, testCase: nil, iteration: nil, configuration: nil),
          messages: [])
        return try JSONEncoder().encode(encodedEvent)
      }()

      Self.enableExperimentalInterop()
      try #require(Event.installFallbackEventHandler(), "Should successfully install a new handler")
      let currentHandler = try #require(
        _swift_testing_getFallbackEventHandler(), "Should successfully retrieved installed handler")

      // Test configuration records all issues actually reported by Testing as a
      // result of the interop issue.
      let issues = Mutex<[Issue]>()
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case .issueRecorded(let issue) = event.kind {
          issues.withLock { $0.append(issue) }
        }
      }

      // Run the test, which should record two issues in response to the interop one
      await Test {
        eventJSON.withUnsafeBytes { ptr in
          let vers = String(describing: ABI.CurrentVersion.versionNumber)
          currentHandler(vers, ptr.baseAddress!, ptr.count, nil)
        }
      }.run(configuration: configuration)

      #expect(
        issues.rawValue.map { $0.description }.sorted() == [
          "An API was misused (warning): XCTest API was used in a Swift Testing test. Adopt Swift Testing primitives, such as #expect, instead.",
          "Issue recorded (error): Unknown issue",
        ]
      )
    }
  }
}
#endif
