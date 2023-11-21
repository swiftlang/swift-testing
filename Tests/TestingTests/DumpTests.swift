//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(InternalDiagnostics) @_spi(ExperimentalTestRunning) import Testing
private import TestingInternals

// NOTE: The tests in this file are here to exercise Plan.dump(), but they are
// not intended to actually test that the output is in a particular format since
// the format is meant to be human-readable and is subject to change over time.

@Suite("Runner.Plan-dumping Tests")
struct DumpTests {
  @Test("Dumping a Runner.Plan", .enabled(if: testsWithSignificantIOAreEnabled), arguments: [true, false])
  func dumpPlan(verbose: Bool) async throws {
    let plan = await Runner.Plan(selecting: DumpedTests.self)

    var buffer = ""
    plan.dump(to: &buffer, verbose: verbose)
    print(buffer)
  }
}

// MARK: - Fixtures

@Suite(.hidden)
struct DumpedTests {
  @Test(.hidden)
  func noop() {}

  @Test(.hidden, arguments: 0 ..< 10)
  func noop(i: Int) {}

  @Test(.hidden, arguments: 0 ..< 10)
  func noop(j: Int) {}

  @Test(.hidden, arguments: 0 ..< 10)
  func noop(i: Int64) {}
}
