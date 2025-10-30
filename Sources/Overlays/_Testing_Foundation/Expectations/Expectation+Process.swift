//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation)
@_spi(ForToolsIntegrationOnly) public import Testing
public import Foundation
private import _TestingInternals

@_spi(Experimental)
@freestanding(expression)
@discardableResult
#if !SWT_NO_EXIT_TESTS
@available(macOS 10.15.4, *)
#else
@_unavailableInEmbedded
@available(*, unavailable, message: "Exit tests are not available on this platform.")
#endif
public macro expect(
  _ process: Process,
  exitsWith expectedExitCondition: ExitTest.Condition,
  observing observedValues: [any PartialKeyPath<ExitTest.Result> & Sendable] = [],
  _ comment: @autoclosure () -> Comment? = nil,
  sourceLocation: SourceLocation = #_sourceLocation
) -> ExitTest.Result? = #externalMacro(module: "TestingMacros", type: "ExpectNSTaskExitsWithMacro")

@_spi(Experimental)
@freestanding(expression)
@discardableResult
#if !SWT_NO_EXIT_TESTS
@available(macOS 10.15.4, *)
#else
@_unavailableInEmbedded
@available(*, unavailable, message: "Exit tests are not available on this platform.")
#endif
public macro require(
  _ process: Process,
  exitsWith expectedExitCondition: ExitTest.Condition,
  observing observedValues: [any PartialKeyPath<ExitTest.Result> & Sendable] = [],
  _ comment: @autoclosure () -> Comment? = nil,
  sourceLocation: SourceLocation = #_sourceLocation
) -> ExitTest.Result = #externalMacro(module: "TestingMacros", type: "RequireNSTaskExitsWithMacro")

// MARK: -

@_spi(Experimental)
@discardableResult
#if !SWT_NO_EXIT_TESTS
@available(macOS 10.15.4, *)
#else
@_unavailableInEmbedded
@available(*, unavailable, message: "Exit tests are not available on this platform.")
#endif
public func __check(
  _ process: Process,
  exitsWith expectedExitCondition: ExitTest.Condition,
  observing observedValues: [any PartialKeyPath<ExitTest.Result> & Sendable] = [],
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation
) async -> Result<ExitTest.Result?, any Error> {
#if !SWT_NO_EXIT_TESTS
  // The process may have already started and may already have a termination
  // handler set, so it's not possible for us to asynchronously wait for it.
  // As such, we'll have to block _some_ thread.
  var result: ExitTest.Result
  do {
    try await withCheckedThrowingContinuation { continuation in
      Thread.detachNewThread {
        do {
          // There's an obvious race condition here, but that's a limitation of
          // the Process/NSTask API and we'll just have to accept it.
          if !process.isRunning {
            try process.run()
          }
          process.waitUntilExit()
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }

    let reason = process.terminationReason
    let exitStatus: ExitStatus = switch reason {
    case .exit:
      .exitCode(process.terminationStatus)
    case .uncaughtSignal:
  #if os(Windows)
      // On Windows, Foundation tries to map exit codes that look like HRESULT
      // values to signals, which is not the model Swift Testing uses. The
      // conversion is lossy, so there's not much we can do here other than treat
      // it as an exit code too.
      .exitCode(process.terminationStatus)
  #else
      .signal(process.terminationStatus)
  #endif
    @unknown default:
      fatalError("Unexpected termination reason '\(reason)' from process \(process). Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new")
    }

    result = ExitTest.Result(exitStatus: exitStatus)
    func makeContent(from streamObject: Any?) -> [UInt8] {
      if let fileHandle = streamObject as? FileHandle {
        if let content = try? fileHandle.readToEnd() {
          return Array(content)
        }
      } else if let pipe = streamObject as? Pipe {
        return makeContent(from: pipe.fileHandleForReading)
      }

      return []
    }
    if observedValues.contains(\.standardOutputContent) {
      result.standardOutputContent = makeContent(from: process.standardOutput)
    }
    if observedValues.contains(\.standardErrorContent) {
      result.standardErrorContent = makeContent(from: process.standardError)
    }
  } catch {
    // As with the main exit test implementation, if an error occurs while
    // trying to run the exit test, treat it as a system error and treat the
    // condition as a mismatch.
    let issue = Issue(
      kind: .system,
      comments: comments() + CollectionOfOne(Comment(rawValue: String(describingForTest: error))),
      sourceContext: SourceContext(backtrace: nil, sourceLocation: sourceLocation)
    )
    issue.record()

    let exitStatus: ExitStatus = if expectedExitCondition.isApproximatelyEqual(to: .exitCode(EXIT_FAILURE)) {
      .exitCode(EXIT_SUCCESS)
    } else {
      .exitCode(EXIT_FAILURE)
    }
    result = ExitTest.Result(exitStatus: exitStatus)
  }

  let expression = Expression("expectedExitCondition")
  return __checkValue(
    expectedExitCondition.isApproximatelyEqual(to: result.exitStatus),
    expression: expression,
    expressionWithCapturedRuntimeValues: expression.capturingRuntimeValues(result.exitStatus),
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  ).map { _ in result }
#else
  swt_unreachable()
#endif
}
#endif
