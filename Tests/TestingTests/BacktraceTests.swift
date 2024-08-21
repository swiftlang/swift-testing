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

struct BacktracedError: Error {}

@Suite("Backtrace Tests")
struct BacktraceTests {
  @Test("Thrown error captures backtrace")
  func thrownErrorCapturesBacktrace() async throws {
    await confirmation("Backtrace found") { hadBacktrace in
      let test = Test {
        throw BacktracedError()
      }
      var configuration = Configuration()
      configuration.eventHandler = { event, _ in
        if case let .issueRecorded(issue) = event.kind,
           let backtrace = issue.sourceContext.backtrace,
           !backtrace.addresses.isEmpty {
          hadBacktrace()
        }
      }
      let runner = await Runner(testing: [test], configuration: configuration)
      await runner.run()
    }
  }

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
