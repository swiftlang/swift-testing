//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import Foundation
private import RegexBuilder

#if !SWT_NO_PROCESS_SPAWNING
extension Event {
  package final class XCTestAdapter: Adapter {
#if SWT_TARGET_OS_APPLE
    private let _testProductPath: String
    private let _xctestToolPath: String

    package init(testProductPath: String, xctestToolPath: String) {
      _testProductPath = testProductPath
      _xctestToolPath = xctestToolPath
    }
#else
    private let _testProductPath: String

    package init(testProductPath: String) {
      _testProductPath = testProductPath
    }
#endif

    package var adapterName: String {
      _testProductPath
    }

    package func run(_ eventHandler: @escaping @Sendable (borrowing Event, borrowing Event.Context) async throws -> Void) async throws {
      try await withThrowingTaskGroup(of: Void.self) { taskGroup in
        var stderrReadEnd: FileHandle!
        var stderrWriteEnd: FileHandle!
        try FileHandle.makePipe(readEnd: &stderrReadEnd, writeEnd: &stderrWriteEnd)

        var arguments = [String]()

#if SWT_TARGET_OS_APPLE
        arguments += [_testProductPath]
        let executablePath = _xctestToolPath
#else
        let executablePath = _testProductPath
#endif

        var environment = Environment.get()
        environment["SWIFT_TESTING_ENABLED"] = "0"

        let processID = try spawnExecutable(
          atPath: executablePath,
          arguments: arguments,
          environment: environment,
          standardOutput: .stdout,
          standardError: stderrWriteEnd
        )
        stderrWriteEnd.close()

        // Wait for the child process to terminate.
        taskGroup.addTask(name: decorateTaskName("harness", withAction: "running XCTest")) {
          _ = try await wait(for: processID)
        }

        // Always write run started/ended events.
        let context = Event.Context(test: nil, testCase: nil, iteration: nil, configuration: nil)
        try await eventHandler(Event(.runStarted, testID: nil, testCaseID: nil), context)
        defer {
          try? await eventHandler(Event(.runEnded, testID: nil, testCaseID: nil), context)
        }

        // Read events back out from the back channel.
        taskGroup.addTask(name: decorateTaskName("harness", withAction: "reading output from XCTest")) { [weak self] in
          var terminator: UInt8?
          repeat {
            let line: [UInt8]
            (line, terminator) = try stderrReadEnd.read(until: \.isASCIINewline)

            // Allow other tasks to run after we may have blocked for some time on
            // I/O with the child process.
            await Task.yield()

            if line.isEmpty {
              continue
            }
            try await self?._handleLine(line, eventHandler: eventHandler)
          } while terminator != nil
        }

        try await taskGroup.waitForAll()
      }
    }

    private static nonisolated(unsafe) let _ignoredRegexes = [
      Regex {
        "Test Suite '"
        OneOrMore(.any)
        "' started at "
      },
      Regex {
        "Test Suite '"
        OneOrMore(.any)
        "' "
        OneOrMore(.any)
        " at "
      },
      Regex {
        "Executed "
        OneOrMore(.digit)
        " test"
        Optionally("s")
        ", with "
        OneOrMore(.digit)
        " failure"
        Optionally("s")
        " ("
        OneOrMore(.digit)
        " unexpected) in "
      }
    ]

    private static nonisolated(unsafe) let _testFunctionStartedRegex = Regex {
      "Test Case '-["
      Capture {
        OneOrMore(.any)
      }
      " "
      Capture {
        OneOrMore(.any)
      }
      "]' started."
    }

    private static nonisolated(unsafe) let _issueRecordedRegex = Regex {
      Capture {
        OneOrMore(.any)
      }
      ":"
      Capture {
        OneOrMore(.digit)
      }
      ": "
      Capture {
        OneOrMore(.word)
      }
      ": -["
      Capture {
        OneOrMore(.any)
      }
      " "
      Capture {
        OneOrMore(.any)
      }
      "] : "
      OneOrMore(.word)
      Optionally(" - ")
      Capture {
        ZeroOrMore(.any)
      }
    }

    private static nonisolated(unsafe) let _testFunctionEndedRegex = Regex {
      "Test Case '-["
      Capture {
        OneOrMore(.any)
      }
      " "
      Capture {
        OneOrMore(.any)
      }
      "]' "
      OneOrMore(.any)
      " ("
      OneOrMore(.any)
      " seconds)."
    }

    private let _currentSuiteTypeInfo = Allocated(Mutex<TypeInfo?>())

    private func _handleLine(_ line: [UInt8], eventHandler: @Sendable (borrowing Event, borrowing Event.Context) async throws -> Void) async throws {
      let line = String(decoding: line, as: UTF8.self)

      if let testFunctionStarted = try Self._testFunctionStartedRegex.firstMatch(in: line) {
        let fullyQualifiedSuiteName = String(testFunctionStarted.1)
        let typeInfo = TypeInfo(fullyQualifiedName: fullyQualifiedSuiteName, mangledName: nil)
        let functionName = String(testFunctionStarted.2)

        let (needSuiteEvents, previousTypeInfo) = _currentSuiteTypeInfo.value.withLock { currentSuiteTypeInfo in
          let result = (currentSuiteTypeInfo != typeInfo, currentSuiteTypeInfo)
          currentSuiteTypeInfo = typeInfo
          return result
        }
        if needSuiteEvents {
          let suite = Test(
            traits: [],
            sourceLocation: .unknown,
            containingTypeInfo: typeInfo
          )
          let context = Event.Context(test: suite, testCase: nil, iteration: nil, configuration: nil)
          do {
            let event = Event(.testDiscovered, testID: suite.id, testCaseID: nil)
            try await eventHandler(event, context)
          }
          if let previousTypeInfo {
            let previousSuite = Test(
              traits: [],
              sourceLocation: .unknown,
              containingTypeInfo: previousTypeInfo
            )
            let context = Event.Context(test: previousSuite, testCase: nil, iteration: nil, configuration: nil)
            do {
              let event = Event(.testEnded, testID: previousSuite.id, testCaseID: nil)
              try await eventHandler(event, context)
            }
          }
          do {
            let event = Event(.testStarted, testID: suite.id, testCaseID: nil)
            try await eventHandler(event, context)
          }
        }

        let test = Test(
          name: functionName,
          displayName: "-[\(typeInfo.fullyQualifiedName) \(functionName)]",
          traits: [],
          sourceBounds: .init(lowerBoundOnly: .unknown),
          containingTypeInfo: typeInfo,
          xcTestCompatibleSelector: nil, // yes yes I know
          testCases: Test.Case.Generator { },
          parameters: []
        )
        let context = Event.Context(test: test, testCase: nil, iteration: nil, configuration: nil)
        do {
          let event = Event(.testDiscovered, testID: test.id, testCaseID: nil)
          try await eventHandler(event, context)
        }
        do {
          let event = Event(.testStarted, testID: test.id, testCaseID: nil)
          try await eventHandler(event, context)
        }
      } else if let issueRecorded = try Self._issueRecordedRegex.firstMatch(in: line) {
        let filePath = String(issueRecorded.1)
        let line = Int(issueRecorded.2) ?? 1
        let sourceLocation = SourceLocation(fileIDSynthesizingIfNeeded: nil, filePath: filePath, line: line, column: 1)
        let severity: Issue.Severity = (issueRecorded.3 == "error") ? .error : .warning
        let fullyQualifiedSuiteName = String(issueRecorded.4)
        let typeInfo = TypeInfo(fullyQualifiedName: fullyQualifiedSuiteName, mangledName: nil)
        let functionName = String(issueRecorded.5)
        var comment: Comment?
        if !issueRecorded.6.isEmpty {
          comment = Comment(rawValue: String(issueRecorded.6))
        }

        let test = Test(
          name: functionName,
          displayName: "-[\(typeInfo.fullyQualifiedName) \(functionName)]",
          traits: [],
          sourceBounds: .init(lowerBoundOnly: .unknown),
          containingTypeInfo: typeInfo,
          xcTestCompatibleSelector: nil, // yes yes I know
          testCases: Test.Case.Generator { },
          parameters: []
        )
        let context = Event.Context(test: test, testCase: nil, iteration: nil, configuration: nil)
        do {
          let sourceContext = SourceContext(backtrace: nil, sourceLocation: sourceLocation)
          let issue = Issue(kind: .unconditional, severity: severity, comments: Array(comment), sourceContext: sourceContext)
          let event = Event(.issueRecorded(issue), testID: test.id, testCaseID: nil)
          try await eventHandler(event, context)
        }

      } else if let testFunctionEnded = try Self._testFunctionEndedRegex.firstMatch(in: line) {
        let fullyQualifiedSuiteName = String(testFunctionEnded.1)
        let typeInfo = TypeInfo(fullyQualifiedName: fullyQualifiedSuiteName, mangledName: nil)
        let functionName = String(testFunctionEnded.2)

        let test = Test(
          name: functionName,
          displayName: "-[\(typeInfo.fullyQualifiedName) \(functionName)]",
          traits: [],
          sourceBounds: .init(lowerBoundOnly: .unknown),
          containingTypeInfo: typeInfo,
          xcTestCompatibleSelector: nil, // yes yes I know
          testCases: Test.Case.Generator { },
          parameters: []
        )
        let context = Event.Context(test: test, testCase: nil, iteration: nil, configuration: nil)
        do {
          let event = Event(.testEnded, testID: test.id, testCaseID: nil)
          try await eventHandler(event, context)
        }
      } else {
        let isExpected = try Self._ignoredRegexes.contains { try $0.firstMatch(in: line) != nil }
        if !isExpected {
          try FileHandle.stderr.write("UNEXPECTED: \(line)\n")
        }
      }
    }
  }
}
#endif
