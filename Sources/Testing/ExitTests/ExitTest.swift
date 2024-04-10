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
/// A type describing an exit test.
///
/// Instances of this type describe an exit test defined by the test author and
/// discovered or called at runtime.
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public struct ExitTest: Sendable {
  /// The expected exit condition of the exit test.
  public var expectedExitCondition: ExitCondition

  /// The body closure of the exit test.
  fileprivate var body: @Sendable () async -> Void

  /// The source location of the exit test.
  ///
  /// The source location is unique to each exit test and is consistent between
  /// processes, so it can be used to uniquely identify an exit test at runtime.
  public var sourceLocation: SourceLocation

  /// Call the exit test in the current process.
  public func callAsFunction() async -> Void {
    await body()
  }
}

// MARK: - Discovery

/// A protocol describing a type that contains an exit test.
///
/// - Warning: This protocol is used to implement the `#expect(exitsWith:)`
///   macro. Do not use it directly.
@_alwaysEmitConformanceMetadata
@_spi(Experimental)
public protocol __ExitTestContainer {
  /// The expected exit condition of the exit test.
  static var __expectedExitCondition: ExitCondition { get }

  /// The source location of the exit test.
  static var __sourceLocation: SourceLocation { get }

  /// The body function of the exit test.
  static var __body: @Sendable () async -> Void { get }
}

extension ExitTest {
  /// A string that appears within all auto-generated types conforming to the
  /// `__ExitTestContainer` protocol.
  private static let _exitTestContainerTypeNameMagic = "__🟠$exit_test_body__"

  /// Find the exit test function at the given source location.
  ///
  /// - Parameters:
  ///   - sourceLocation: The source location of the exit test to find.
  ///
  /// - Returns: The specified exit test function, or `nil` if no such exit test
  ///   could be found.
  public static func find(at sourceLocation: SourceLocation) -> Self? {
    struct Context {
      var sourceLocation: SourceLocation
      var result: ExitTest?
    }
    var context = Context(sourceLocation: sourceLocation)
    withUnsafeMutablePointer(to: &context) { context in
      swt_enumerateTypes(context) { type, context in
        let context = context!.assumingMemoryBound(to: (Context).self)
        if let type = unsafeBitCast(type, to: Any.Type.self) as? any __ExitTestContainer.Type,
           type.__sourceLocation == context.pointee.sourceLocation {
          context.pointee.result = ExitTest(
            expectedExitCondition: type.__expectedExitCondition,
            body: type.__body,
            sourceLocation: type.__sourceLocation
          )
          return false
        }
        return true
      } withNamesMatching: { typeName, _ in
        // strstr() lets us avoid copying either string before comparing.
        Self._exitTestContainerTypeNameMagic.withCString { testContainerTypeNameMagic in
          nil != strstr(typeName, testContainerTypeNameMagic)
        }
      }
    }

    if var result = context.result {
      // Add some glue code that terminates the process with an exit condition
      // that does not match the expected one. If the exit test's body doesn't
      // terminate, we'll manually call exit() and cause the test to fail.
      let expectingFailure = result.expectedExitCondition.matches(.failure)
      result.body = { [body = result.body] in
        await body()
        exit(expectingFailure ? EXIT_SUCCESS : EXIT_FAILURE)
      }
      return result
    }

    return nil
  }
}

// MARK: -

/// Check that an expression always exits (terminates the current process) with
/// a given status.
///
/// - Parameters:
///   - expectedExitCondition: The expected exit condition.
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
  exitsWith expectedExitCondition: ExitCondition,
  performing body: @escaping @Sendable () async -> Void,
  expression: Expression,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) async -> Result<Void, any Error> {
  // FIXME: use lexicalContext to capture these misuses at compile time.
  guard let configuration = Configuration.current, Test.current != nil else {
    preconditionFailure("A test must be running on the current task to use #expect(exitsWith:).")
  }

  let actualExitCondition: ExitCondition
  do {
    let exitTest = ExitTest(expectedExitCondition: expectedExitCondition, body: body, sourceLocation: sourceLocation)
    guard let exitCondition = try await configuration.exitTestHandler(exitTest) else {
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
    expectedExitCondition.matches(actualExitCondition),
    expression: expression,
    expressionWithCapturedRuntimeValues: expression.capturingRuntimeValues(actualValue),
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}

// MARK: - SwiftPM/tools integration

extension ExitTest {
  /// A handler that is invoked when an exit test starts.
  ///
  /// - Parameters:
  ///   - exitTest: The exit test that is starting.
  ///
  /// - Returns: The condition under which the exit test exited, or `nil` if the
  ///   exit test was not invoked.
  ///
  /// - Throws: Any error that prevents the normal invocation or execution of
  ///   the exit test.
  ///
  /// This handler is invoked when an exit test (i.e. a call to either
  /// ``expect(exitsWith:_:sourceLocation:performing:)`` or
  /// ``require(exitsWith:_:sourceLocation:performing:)``) is started. The
  /// handler is responsible for initializing a new child environment (typically
  /// a child process) and running the exit test identified by `sourceLocation`
  /// there. The exit test's body can be found using ``ExitTest/find(at:)``.
  ///
  /// The parent environment should suspend until the results of the exit test
  /// are available or the child environment is otherwise terminated. The parent
  /// environment is then responsible for interpreting those results and
  /// recording any issues that occur.
  public typealias Handler = @Sendable (_ exitTest: borrowing ExitTest) async throws -> ExitCondition?

  /// Find the exit test function specified by the given command-line arguments,
  /// if any.
  ///
  /// - Parameters:
  ///   - args: The command-line arguments to this process.
  ///
  /// - Returns: The exit test this process should run, or `nil` if it is not
  ///   expected to run any.
  ///
  /// This function should only be used when the process was started via the
  /// `__swiftPMEntryPoint()` function. The effect of using it under other
  /// configurations is undefined.
  public static func find(withArguments args: [String]) -> Self? {
    let sourceLocationString = Environment.variable(named: "SWT_EXPERIMENTAL_EXIT_TEST_SOURCE_LOCATION")
    if let sourceLocationData = sourceLocationString?.data(using: .utf8),
       let sourceLocation = try? JSONDecoder().decode(SourceLocation.self, from: sourceLocationData) {
      return find(at: sourceLocation)
    }
    return nil
  }

  /// The exit test handler used when integrating with Swift Package Manager via
  /// the `__swiftPMEntryPoint()` function.
  ///
  /// - Parameters:
  ///   - xcTestCaseIdentifier: The identifier of the XCTest-based test hosting
  ///     the testing library (when using ``XCTestScaffold``.)
  ///
  /// For a description of the inputs and outputs of this function, see the
  /// documentation for ``ExitTest/Handler``.
  static func handlerForSwiftPM(forXCTestCaseIdentifiedBy xcTestCaseIdentifier: String? = nil) -> Handler {
    let parentEnvironment = ProcessInfo.processInfo.environment

    return { exitTest in
      let actualExitCode: Int32
      let wasSignalled: Bool
      do {
        let childProcessURL: URL = try URL(fileURLWithPath: CommandLine.executablePath, isDirectory: false)

        // We only need to pass arguments when hosted by XCTest.
        var childArguments = [String]()
        if let xcTestCaseIdentifier {
#if os(macOS)
          childArguments += ["-XCTest", xcTestCaseIdentifier]
#else
          childArguments.append(xcTestCaseIdentifier)
#endif
          if let xctestTargetPath = parentEnvironment["XCTestBundlePath"] {
            childArguments.append(xctestTargetPath)
          } else if let xctestTargetPath = CommandLine.arguments().last {
            childArguments.append(xctestTargetPath)
          }
        }

        // Inherit the environment from the parent process and add our own
        // variable indicating which exit test will run, then make any necessary
        // platform-specific changes.
        var childEnvironment: [String: String] = parentEnvironment
        childEnvironment["SWT_EXPERIMENTAL_EXIT_TEST_SOURCE_LOCATION"] = try String(data: JSONEncoder().encode(exitTest.sourceLocation), encoding: .utf8)!
#if SWT_TARGET_OS_APPLE
        if childEnvironment["XCTestSessionIdentifier"] != nil {
          // We need to remove Xcode's environment variables from the child
          // environment to avoid accidentally accidentally recursing.
          for key in childEnvironment.keys where key.starts(with: "XCTest") {
            childEnvironment.removeValue(forKey: key)
          }
        }
#elseif os(Linux)
        if childEnvironment["SWIFT_BACKTRACE"] == nil {
          // Disable interactive backtraces unless explicitly enabled to reduce
          // the noise level during the exit test. Only needed on Linux.
          childEnvironment["SWIFT_BACKTRACE"] = "enable=no"
        }
#endif

        (actualExitCode, wasSignalled) = try await withCheckedThrowingContinuation { continuation in
          do {
            let process = Process()
            process.executableURL = childProcessURL
            process.arguments = childArguments
            process.environment = childEnvironment
            process.terminationHandler = { process in
              continuation.resume(returning: (process.terminationStatus, process.terminationReason == .uncaughtSignal))
            }
            try process.run()
          } catch {
            continuation.resume(throwing: error)
          }
        }

        if wasSignalled {
#if os(Windows)
          // Actually an uncaught SEH/VEH exception (which we don't model yet.)
          return .failure
#else
          return .signal(actualExitCode)
#endif
        }
        return .exitCode(actualExitCode)
      }
    }
  }
}
#endif
