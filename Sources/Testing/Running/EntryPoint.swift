//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_implementationOnly import TestingInternals

#if !SWT_TARGET_OS_APPLE
/// The entry point to the testing library used by Swift Package Manager.
///
/// - Returns: The result of invoking the testing library. The type of this
///   value is subject to change.
///
/// This function examines the command-line arguments to the current process
/// and then invokes available tests in the current process.
///
/// - Warning: This function is used by Swift Package Manager. Do not call it
///   directly.
@_spi(SwiftPackageManagerSupport)
public func __swiftPMEntryPoint() async -> CInt {
  let args = CommandLine.arguments()
  // We do not use --dump-tests-json to handle test list requests. If that
  // argument is passed, just exit early.
  if args.contains("--dump-tests-json") {
    return EXIT_SUCCESS
  }

  @Locked var exitCode = EXIT_SUCCESS
  await runTests { event, _ in
    if case let .issueRecorded(issue) = event.kind, !issue.isKnown {
      $exitCode.withLock { exitCode in
        exitCode = EXIT_FAILURE
      }
    }
  }
  return exitCode
}
#endif

/// The common implementation of `__main()` and
/// ``XCTestScaffold/runAllTests(hostedBy:)``.
///
/// - Parameters:
///   - testIDs: The test IDs to run. If `nil`, all tests are run.
///   - tags: The tags to filter by (only tests with one or more of these tags
///     will be run.)
///   - eventHandler: An event handler to invoke after events are written to
///     the standard error stream.
func runTests(identifiedBy testIDs: [Test.ID]? = nil, taggedWith tags: Set<Tag>? = nil, eventHandler: @escaping Event.Handler = { _, _ in }) async {
  let eventRecorder = Event.Recorder(options: .forStandardError) { string in
    let stderr = swt_stderr()
    fputs(string, stderr)
    fflush(stderr)
  }

  var configuration = Configuration()
  configuration.isParallelizationEnabled = false
  configuration.eventHandler = { event, context in
    eventRecorder.record(event, in: context)
    eventHandler(event, context)
  }
  
  if let testIDs {
    configuration.setTestFilter(toMatch: Set(testIDs))
  }
  if let tags {
    // Check if the test's tags intersect the set of selected tags. If there
    // was a previous filter function, it must also pass.
    let oldTestFilter = configuration.testFilter ?? { _ in true }
    configuration.testFilter = { test in
      !tags.isDisjoint(with: test.tags) && oldTestFilter(test)
    }
  }

  let runner = await Runner(configuration: configuration)
  await runner.run()
}
