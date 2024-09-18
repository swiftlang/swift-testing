//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

#if !SWT_NO_EXIT_TESTS
#if SWT_NO_PIPES
#error("Support for exit tests requires support for (anonymous) pipes.")
#endif

/// A type describing an exit test.
///
/// Instances of this type describe an exit test defined by the test author and
/// discovered or called at runtime.
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public struct ExitTest: Sendable, ~Copyable {
  /// The expected exit condition of the exit test.
  public var expectedExitCondition: ExitCondition

  /// The body closure of the exit test.
  fileprivate var body: @Sendable () async throws -> Void = {}

  /// The source location of the exit test.
  ///
  /// The source location is unique to each exit test and is consistent between
  /// processes, so it can be used to uniquely identify an exit test at runtime.
  public var sourceLocation: SourceLocation

  /// Disable crash reporting, crash logging, or core dumps for the current
  /// process.
  private static func _disableCrashReporting() {
#if SWT_TARGET_OS_APPLE && !SWT_NO_MACH_PORTS
    // We don't need to create a crash log (a "corpse notification") for an exit
    // test. In the future, we might want to investigate actually setting up a
    // listener port in the parent process and tracking interesting exceptions
    // as separate exit conditions.
    //
    // BUG: The system may still opt to write crash logs to /Library/Logs
    // instead of the user's home folder. rdar://47982238
    _ = task_set_exception_ports(
      swt_mach_task_self(),
      exception_mask_t(EXC_MASK_CORPSE_NOTIFY),
      mach_port_t(MACH_PORT_NULL),
      EXCEPTION_DEFAULT,
      THREAD_STATE_NONE
    )
#elseif os(Linux) || os(FreeBSD)
    // On Linux and FreeBSD, disable the generation of core files (although they
    // will often be disabled by default.) If a particular Linux distro performs
    // additional crash diagnostics, we may want to special-case them as well if we can.
    var rl = rlimit(rlim_cur: 0, rlim_max: 0)
    _ = setrlimit(CInt(RLIMIT_CORE.rawValue), &rl)
#elseif os(Windows)
    // On Windows, similarly disable Windows Error Reporting and the Windows
    // Error Reporting UI. Note we expect to be the first component to call
    // these functions, so we don't attempt to preserve any previously-set bits.
    _ = SetErrorMode(UINT(SEM_NOGPFAULTERRORBOX))
    _ = WerSetFlags(DWORD(WER_FAULT_REPORTING_NO_UI))
#endif
  }

  /// Call the exit test in the current process.
  ///
  /// This function invokes the closure originally passed to
  /// `#expect(exitsWith:)` _in the current process_. That closure is expected
  /// to terminate the process; if it does not, the testing library will
  /// terminate the process in a way that causes the corresponding expectation
  /// to fail.
  public consuming func callAsFunction() async -> Never {
    Self._disableCrashReporting()

    do {
      try await body()
    } catch {
      _errorInMain(error)
    }

    // Run some glue code that terminates the process with an exit condition
    // that does not match the expected one. If the exit test's body doesn't
    // terminate, we'll manually call exit() and cause the test to fail.
    let expectingFailure = expectedExitCondition == .failure
    exit(expectingFailure ? EXIT_SUCCESS : EXIT_FAILURE)
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
  static var __body: @Sendable () async throws -> Void { get }
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
    var result: Self?

    enumerateTypes(withNamesContaining: _exitTestContainerTypeNameMagic) { type, stop in
      if let type = type as? any __ExitTestContainer.Type, type.__sourceLocation == sourceLocation {
        result = ExitTest(
          expectedExitCondition: type.__expectedExitCondition,
          body: type.__body,
          sourceLocation: type.__sourceLocation
        )
        stop = true
      }
    }

    return result
  }
}

// MARK: -

/// Check that an expression always exits (terminates the current process) with
/// a given status.
///
/// - Parameters:
///   - expectedExitCondition: The expected exit condition.
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
  performing _: @escaping @Sendable () async throws -> Void,
  expression: __Expression,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) async -> Result<Void, any Error> {
  guard let configuration = Configuration.current ?? Configuration.all.first else {
    preconditionFailure("A test must be running on the current task to use #expect(exitsWith:).")
  }

  let actualExitCondition: ExitCondition
  do {
    let exitTest = ExitTest(expectedExitCondition: expectedExitCondition, sourceLocation: sourceLocation)
    actualExitCondition = try await configuration.exitTestHandler(exitTest)
  } catch {
    // An error here would indicate a problem in the exit test handler such as a
    // failure to find the process' path, to construct arguments to the
    // subprocess, or to spawn the subprocess. These are not expected to be
    // common issues, however they would constitute a failure of the test
    // infrastructure rather than the test itself and perhaps should not cause
    // the test to terminate early.
    let issue = Issue(kind: .errorCaught(error), comments: comments(), sourceContext: .init(backtrace: .current(), sourceLocation: sourceLocation))
    issue.record(configuration: configuration)

    return __checkValue(
      false,
      expression: expression,
      comments: comments(),
      isRequired: isRequired,
      sourceLocation: sourceLocation
    )
  }

  return __checkValue(
    expectedExitCondition == actualExitCondition,
    expression: expression,
    expressionWithCapturedRuntimeValues: expression.capturingRuntimeValues(actualExitCondition),
    mismatchedExitConditionDescription: String(describingForTest: expectedExitCondition),
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
  /// - Returns: The condition under which the exit test exited.
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
  public typealias Handler = @Sendable (_ exitTest: borrowing ExitTest) async throws -> ExitCondition

  /// Find the exit test function specified in the environment of the current
  /// process, if any.
  ///
  /// - Returns: The exit test this process should run, or `nil` if it is not
  ///   expected to run any.
  ///
  /// This function should only be used when the process was started via the
  /// `__swiftPMEntryPoint()` function. The effect of using it under other
  /// configurations is undefined.
  static func findInEnvironmentForEntryPoint() -> Self? {
    if var sourceLocationString = Environment.variable(named: "SWT_EXPERIMENTAL_EXIT_TEST_SOURCE_LOCATION") {
      let sourceLocation = try? sourceLocationString.withUTF8 { sourceLocationBuffer in
        let sourceLocationBuffer = UnsafeRawBufferPointer(sourceLocationBuffer)
        return try JSON.decode(SourceLocation.self, from: sourceLocationBuffer)
      }
      if let sourceLocation {
        return find(at: sourceLocation)
      }
    }
    return nil
  }

  /// The exit test handler used when integrating with Swift Package Manager via
  /// the `__swiftPMEntryPoint()` function.
  ///
  /// For a description of the inputs and outputs of this function, see the
  /// documentation for ``ExitTest/Handler``.
  static func handlerForEntryPoint() -> Handler {
    // The environment could change between invocations if a test calls setenv()
    // or unsetenv(), so we need to recompute the child environment each time.
    // The executable and XCTest bundle paths should not change over time, so we
    // can precompute them.
    let childProcessExecutablePath = Result { try CommandLine.executablePath }

    // Construct appropriate arguments for the child process. Generally these
    // arguments are going to be whatever's necessary to respawn the current
    // executable and get back into Swift Testing.
    let childArguments: [String] = {
      var result = [String]()

      let parentArguments = CommandLine.arguments
#if SWT_TARGET_OS_APPLE
      lazy var xctestTargetPath = Environment.variable(named: "XCTestBundlePath")
        ?? parentArguments.dropFirst().last
      // If the running executable appears to be the XCTest runner executable in
      // Xcode, figure out the path to the running XCTest bundle. If we can find
      // it, then we can re-run the host XCTestCase instance.
      var isHostedByXCTest = false
      if let executablePath = try? childProcessExecutablePath.get() {
        executablePath.withCString { childProcessExecutablePath in
          withUnsafeTemporaryAllocation(of: CChar.self, capacity: strlen(childProcessExecutablePath) + 1) { baseName in
            if nil != basename_r(childProcessExecutablePath, baseName.baseAddress!) {
              isHostedByXCTest = 0 == strcmp(baseName.baseAddress!, "xctest")
            }
          }
        }
      }

      if isHostedByXCTest, let xctestTargetPath {
        // HACK: if the current test is being run from within Xcode, we don't
        // always know we're being hosted by an XCTestCase instance. In cases
        // where we don't, but the XCTest environment variable specifying the
        // test bundle is set, assume we _are_ being hosted and specify a
        // blank test identifier ("/") to force the xctest command-line tool
        // to run.
        result += ["-XCTest", "/", xctestTargetPath]
      }

      // When hosted by Swift Package Manager, forward all arguments to the
      // child process. (They aren't all meaningful in the context of an exit
      // test, but it keeps this code fairly simple!)
      lazy var isHostedBySwiftPM = parentArguments.contains("--test-bundle-path")
      if !isHostedByXCTest && isHostedBySwiftPM {
        result += parentArguments.dropFirst()
      }
#else
      // When hosted by Swift Package Manager, we'll need to specify exactly
      // which testing library to call into from the shared test executable.
      let hasTestingLibraryArgument: Bool = parentArguments.contains { $0.starts(with: "--testing-library") }
      if hasTestingLibraryArgument {
        result += ["--testing-library", "swift-testing"]
      }
#endif

      return result
    }()

    return { exitTest in
      let childProcessExecutablePath = try childProcessExecutablePath.get()

      // Inherit the environment from the parent process and make any necessary
      // platform-specific changes.
      var childEnvironment = Environment.get()
#if SWT_TARGET_OS_APPLE
      // We need to remove Xcode's environment variables from the child
      // environment to avoid accidentally accidentally recursing.
      for key in childEnvironment.keys where key.starts(with: "XCTest") {
        childEnvironment.removeValue(forKey: key)
      }
#endif

      if childEnvironment["SWIFT_BACKTRACE"] == nil {
        // Disable interactive backtraces unless explicitly enabled to reduce
        // the noise level during the exit test.
        childEnvironment["SWIFT_BACKTRACE"] = "enable=no"
      }

      // Insert a specific variable that tells the child process which exit test
      // to run.
      try JSON.withEncoding(of: exitTest.sourceLocation) { json in
        childEnvironment["SWT_EXPERIMENTAL_EXIT_TEST_SOURCE_LOCATION"] = String(decoding: json, as: UTF8.self)
      }

      return try await spawnAndWait(
        forExecutableAtPath: childProcessExecutablePath,
        arguments: childArguments,
        environment: childEnvironment
      )
    }
  }
}
#endif
