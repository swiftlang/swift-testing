//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals
@testable @_spi(ForToolsIntegrationOnly) import Testing

#if canImport(Foundation)
import Foundation
#endif

#if !SWT_NO_EXIT_TESTS && compiler(>=6.3) && !SWT_NO_INTEROP && canImport(Foundation)
struct EventHandlingInteropTests {
  private typealias InstallFallbackEventHandler =
    @convention(c) (SWTFallbackEventHandler) -> CBool
  private static let installer: InstallFallbackEventHandler? = {
    symbol(named: "_swift_testing_installFallbackEventHandler").map {
      castCFunction(at: $0, to: InstallFallbackEventHandler.self)
    }
  }()

  static let handlerContents = Mutex<(version: String, record: String?)?>()

  private static let capturingHandler: SWTFallbackEventHandler = { schemaVersion, recordJSONBaseAddress, recordJSONByteCount, _ in
    let version = String(cString: schemaVersion)
    let record = String(
      data: Data(bytes: recordJSONBaseAddress, count: recordJSONByteCount),
      encoding: .utf8)
    Self.handlerContents.withLock {
      $0 = (version: version, record: record)
    }
  }

  /// This uses an exit test to run in a clean process, ensuring that the
  /// installed fallback event handler does not affect other tests.
  ///
  /// Note this test will no longer work once Swift Testing starts installing
  /// its own fallback handler.
  @Test func `Post event without config -> fallback handler`() async throws {
    await #expect(processExitsWith: .success) {
      let installer = try #require(Self.installer)
      try #require(
        installer(Self.capturingHandler), "Installation of fallback handler should succeed")

      // The detached task forces the event to be posted when Configuration.current
      // is nil and triggers the post to fallback handler path
      await Task.detached {
        Event.post(.issueRecorded(Issue(kind: .system)), configuration: nil)
      }.value

      // Assert that the expectation failure contents were sent to the fallback event handler
      try Self.handlerContents.withLock {
        let contents = try #require(
          $0, "Fallback should have been called with non nil contents")
        #expect(contents.version == "6.3")
        #expect(contents.record?.contains("A system failure occurred") ?? false)
      }
    }
  }
}
#endif
