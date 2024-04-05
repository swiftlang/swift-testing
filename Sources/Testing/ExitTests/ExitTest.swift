//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import TestingInternals
#if canImport(Foundation)
private import Foundation
#endif

#if !SWT_NO_EXIT_TESTS
/// A handler that is invoked when an exit test starts.
///
/// - Parameters:
///   - test: The test in which the exit test is running.
///   - exitTestSourceLocation: The source location of the exit test that is
///     starting; the source location is unique to each exit test and is
///     consistent between processes, so it can be used to uniquely identify an
///     exit test at runtime.
///   - body: The body of the exit test.
///
/// - Returns: The condition under which the exit test exited, or `nil` if the
///   exit test was not invoked.
///
/// - Throws: Any error that prevents the normal invocation or execution of the
///   exit test.
///
/// This handler is invoked when an exit test (i.e. a call to either
/// ``expect(exitsWith:_:sourceLocation:performing:)`` or
/// ``require(exitsWith:_:sourceLocation:performing:)``) is started. The handler
/// is responsible for initializing a new child environment (typically a child
/// process) and using an instance of ``Runner`` to run `test` in the new
/// environment. The parent environment should suspend until the results of the
/// exit test are available or the child environment is otherwise terminated.
/// The parent environment is then responsible for interpreting those results
/// and recording any issues that occur.
///
/// When `test` is run in the child environment and an exit test is started, the
/// exit test handler configured in the child environment is called. The exit
/// test handler should check that `test` and `exitTestSourceLocation` match
/// those from the parent environment. If they do match, the exit test handler
/// should call `body`.
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public typealias ExitTestHandler = @Sendable (_ test: borrowing Test, _ exitTestSourceLocation: SourceLocation, _ body: () async -> Void) async throws -> ExitCondition?

// MARK: -

public protocol __ExitTestContainer {
  static var __sourceLocation: SourceLocation { get }
  static var __body: @Sendable () async -> Void { get }
}

/// A string that appears within all auto-generated types conforming to the
/// `__TestContainer` protocol.
private let _exitTestContainerTypeNameMagic = "__🟠$exit_test_body__"

func findExitTest(at sourceLocation: SourceLocation) -> (@Sendable () async -> Void)? {
  struct Context {
    var sourceLocation: SourceLocation
    var body: (@Sendable () async -> Void)?
  }
  var context = Context(sourceLocation: sourceLocation)
  withUnsafeMutablePointer(to: &context) { context in
    swt_enumerateTypes(context)  { type, context in
      let context = context!.assumingMemoryBound(to: (Context).self)
      if let type = unsafeBitCast(type, to: Any.Type.self) as? any __ExitTestContainer.Type,
         type.__sourceLocation == context.pointee.sourceLocation {
        context.pointee.body = type.__body
      }
    } withNamesMatching: { typeName, _ in
      // strstr() lets us avoid copying either string before comparing.
      _exitTestContainerTypeNameMagic.withCString { testContainerTypeNameMagic in
        nil != strstr(typeName, testContainerTypeNameMagic)
      }
    }
  }
  return context.body
}

/// A type that provides task-local context for exit tests.
private enum _ExitTestContext {
  /// Whether or not the current process and task are running an exit test.
  @TaskLocal
  static var isRunning = false
}

/// Check that an expression always exits (terminates the current process) with
/// a given status.
///
/// - Parameters:
///   - exitCondition: The expected exit condition.
///   - body: The exit test body.
///   - expression: The expression, corresponding to `condition`, that is being
///     evaluated (if available at compile time.)
///   - comments: An array of comments describing the expectation. This array
///     may be empty.
///   - isRequired: Whether or not the expectation is required. The value of
///     this argument does not affect whether or not an error is thrown on
///     failure.
///   - sourceLocation: The source location of the expectation.
///
/// This function contains the common implementation for all
/// `await #expect(exitsWith:) { }` invocations regardless of calling
/// convention.
func callExitTest(
  exitsWith exitCondition: ExitCondition,
  performing body: () async -> Void,
  expression: Expression,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) async -> Result<Void, any Error> {
  // FIXME: use lexicalContext to capture this misuse at compile time.
  precondition(!_ExitTestContext.isRunning, "Running an exit test within another exit test is unsupported.")

  // FIXME: use lexicalContext to capture these misuses at compile time.
  guard let configuration = Configuration.current, let test = Test.current else {
    preconditionFailure("A test must be running on the current task to use #expect(exitsWith:).")
  }

  let actualExitCondition: ExitCondition
  do {
    guard let exitCondition = try await configuration.exitTestHandler(test, sourceLocation, body) else {
      // This exit test was not run by the handler. Return successfully (and
      // move on to the next one.)
      return __checkValue(
        true,
        expression: expression,
        comments: comments(),
        isRequired: isRequired,
        sourceLocation: sourceLocation
      )
    }
    actualExitCondition = exitCondition
  } catch {
    // An error here would indicate a problem in the exit test handler such as a
    // failure to find the process' path, to construct arguments to the
    // subprocess, or to spawn the subprocess. These are not expected to be
    // common issues, however they would constitute a failure of the test
    // infrastructure rather than the test itself and perhaps should not cause
    // the test to terminate early.
    Issue.record(.errorCaught(error), comments: comments(), backtrace: .current(), sourceLocation: sourceLocation, configuration: configuration)
    return __checkValue(
      false,
      expression: expression,
      comments: comments(),
      isRequired: isRequired,
      sourceLocation: sourceLocation
    )
  }

  lazy var actualValue: CInt? = switch actualExitCondition {
  case .failure:
    nil
  case let .exitCode(exitCode):
    exitCode
#if !os(Windows)
  case let .signal(signal):
    signal
#endif
  }

  return __checkValue(
    exitCondition.matches(actualExitCondition),
    expression: expression,
    expressionWithCapturedRuntimeValues: expression.capturingRuntimeValues(actualValue),
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

// MARK: - SwiftPM integration

#if SWIFT_PM_SUPPORTS_SWIFT_TESTING
/// Get the source location of the exit test this process should run, if any.
///
/// - Parameters:
///   - args: The command-line arguments to this process.
///
/// - Returns: The source location of the exit test this process should run, or
///   `nil` if it is not expected to run any.
///
/// This function should only be used when the process was started via the
/// `__swiftPMEntryPoint()` function. The effect of using it under other
/// configurations is undefined.
func currentExitTestSourceLocation(withArguments args: [String] = CommandLine.arguments()) -> SourceLocation? {
  if let runArgIndex = args.firstIndex(of: "--experimental-run-exit-test-body-at"), runArgIndex < args.endIndex {
    if let sourceLocationData = args[args.index(after: runArgIndex)].data(using: .utf8) {
      return try? JSONDecoder().decode(SourceLocation.self, from: sourceLocationData)
    }
  }
  return nil
}

/// The exit test handler used when integrating with Swift Package Manager via
/// the `__swiftPMEntryPoint()` function.
///
/// For a description of the inputs and outputs of this function, see the
/// documentation for ``ExitTestHandler``.
@Sendable func exitTestHandlerForSwiftPM(
  _ test: borrowing Test,
  exitTestSourceLocation sourceLocation: SourceLocation,
  body: () async -> Void
) async throws -> ExitCondition? {
  let actualExitCode: Int32
  let wasSignalled: Bool
  do {
    let childProcessURL: URL = try URL(fileURLWithPath: CommandLine.executablePath, isDirectory: false)
    let escapedTestID: String = String(describing: test.id).lazy
      .map { character in
        if character.isLetter || character.isWholeNumber {
          String(character)
        } else {
          #"\\#(character)"#
        }
      }.joined()
    let childArguments = [
      "--experimental-run-exit-test-body-at",
      try String(data: JSONEncoder().encode(sourceLocation), encoding: .utf8)!,
    ]
    // By default, inherit the environment from the parent process.
    var childEnvironment: [String: String]? = nil
#if os(Linux)
    if Environment.variable(named: "SWIFT_BACKTRACE") == nil {
      // Disable interactive backtraces unless explicitly enabled to reduce
      // the noise level during the exit test. Only needed on Linux.
      childEnvironment = ProcessInfo.processInfo.environment
      childEnvironment?["SWIFT_BACKTRACE"] = "enable=no"
    }
#endif

    (actualExitCode, wasSignalled) = try await withCheckedThrowingContinuation { continuation in
      do {
        let process = Process()
        process.executableURL = childProcessURL
        process.arguments = childArguments
        if let childEnvironment {
          process.environment = childEnvironment
        }
        process.terminationHandler = { process in
          continuation.resume(returning: (process.terminationStatus, process.terminationReason == .uncaughtSignal))
        }
        try process.run()
      } catch {
        continuation.resume(throwing: error)
      }
    }

#if !os(Windows)
    if wasSignalled {
      return .signal(actualExitCode)
    }
#endif
    return .exitCode(actualExitCode)
  }
}
#endif
#endif
