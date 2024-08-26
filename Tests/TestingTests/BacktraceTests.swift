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
#if SWT_TARGET_OS_APPLE && canImport(Foundation)
import Foundation
#endif

struct BacktracedError: Error {}
final class BacktracedRefCountedError: Error {}

@Suite("Backtrace Tests")
struct BacktraceTests {
  @Test("Thrown error captures backtrace")
  func thrownErrorCapturesBacktrace() async throws {
    await confirmation("Backtrace found", expectedCount: 2) { hadBacktrace in
      let testValueType = Test {
        throw BacktracedError()
      }
      let testReferenceType = Test {
        throw BacktracedRefCountedError()
      }
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case let .issueRecorded(issue) = event.kind,
           let backtrace = issue.sourceContext.backtrace,
           !backtrace.addresses.isEmpty {
          hadBacktrace()
        }
      }
      let runner = await Runner(testing: [testValueType, testReferenceType], configuration: configuration)
      await runner.run()
    }
  }

  @available(_typedThrowsAPI, *)
  @Test("Typed thrown error captures backtrace")
  func typedThrownErrorCapturesBacktrace() async throws {
    await confirmation("Error recorded", expectedCount: 4) { errorRecorded in
      await confirmation("Backtrace found", expectedCount: 2) { hadBacktrace in
        let testValueType = Test {
          try Result<Never, _>.failure(BacktracedError()).get()
        }
        let testReferenceType = Test {
          try Result<Never, _>.failure(BacktracedRefCountedError()).get()
        }
        let testAnyType = Test {
          try Result<Never, any Error>.failure(BacktracedError()).get()
        }
        let testAnyObjectType = Test {
          try Result<Never, any Error>.failure(BacktracedRefCountedError()).get()
        }
        var configuration = Configuration()
        configuration.eventHandler = { event, _ in
          if case let .issueRecorded(issue) = event.kind {
            errorRecorded()
            if let backtrace = issue.sourceContext.backtrace, !backtrace.addresses.isEmpty {
              hadBacktrace()
            }
          }
        }
        let runner = await Runner(testing: [testValueType, testReferenceType, testAnyType, testAnyObjectType], configuration: configuration)
        await runner.run()
      }
    }
  }

#if SWT_TARGET_OS_APPLE && canImport(Foundation)
  @available(_typedThrowsAPI, *)
  @Test("Thrown NSError captures backtrace")
  func thrownNSErrorCapturesBacktrace() async throws {
    await confirmation("Backtrace found", expectedCount: 2) { hadBacktrace in
      let testValueType = Test {
        throw NSError(domain: "", code: 0, userInfo: [:])
      }
      let testReferenceType = Test {
        try Result<Never, any Error>.failure(NSError(domain: "", code: 0, userInfo: [:])).get()
      }
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case let .issueRecorded(issue) = event.kind,
           let backtrace = issue.sourceContext.backtrace,
           !backtrace.addresses.isEmpty {
          hadBacktrace()
        }
      }
      let runner = await Runner(testing: [testValueType, testReferenceType], configuration: configuration)
      await runner.run()
    }
  }
#endif

  @Test("Backtrace.current() is populated")
  func currentBacktrace() {
    let backtrace = Backtrace.current()
    #expect(!backtrace.addresses.isEmpty)
  }

  @Test("An unthrown error has no backtrace")
  func noBacktraceForNewError() throws {
    #expect(Backtrace(forFirstThrowOf: BacktracedError()) == nil)
  }

#if canImport(Foundation)
  @Test("Encoding/decoding")
  func encodingAndDecoding() throws {
    let original = Backtrace.current()
    let copy = try JSON.encodeAndDecode(original)
    #expect(original == copy)
  }
#endif
}
