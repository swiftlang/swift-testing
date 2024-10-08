//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) private import _TestDiscovery
private import _TestingInternals

#if !SWT_NO_EXIT_TESTS
#if SWT_NO_FILE_IO
#error("Platform-specific misconfiguration: support for exit tests requires support for file I/O")
#endif
#if SWT_NO_PIPES
#error("Platform-specific misconfiguration: support for exit tests requires support for (anonymous) pipes")
#endif
#if SWT_NO_PROCESS_SPAWNING
#error("Platform-specific misconfiguration: support for exit tests requires support for process spawning")
#endif
#endif

/// A type describing an exit test.
///
/// Instances of this type describe exit tests you create using the
/// ``expect(exitsWith:observing:_:sourceLocation:performing:)``
/// ``require(exitsWith:observing:_:sourceLocation:performing:)`` macro. You
/// don't usually need to interact directly with an instance of this type.
@_spi(Experimental)
#if SWT_NO_EXIT_TESTS
@available(*, unavailable, message: "Exit tests are not available on this platform.")
#endif
public struct ExitTest: Sendable, ~Copyable {
  /// A type whose instances uniquely identify instances of ``ExitTest``.
  @_spi(ForToolsIntegrationOnly)
  public struct ID: Sendable, Equatable, Codable {
    /// An underlying UUID (stored as two `UInt64` values to avoid relying on
    /// `UUID` from Foundation or any platform-specific interfaces.)
    private var _lo: UInt64
    private var _hi: UInt64

    init(_ uuid: (UInt64, UInt64)) {
      self._lo = uuid.0
      self._hi = uuid.1
    }
  }

  /// A value that uniquely identifies this instance.
  @_spi(ForToolsIntegrationOnly)
  public var id: ID

  /// The body closure of the exit test.
  ///
  /// Do not invoke this closure directly. Instead, invoke ``callAsFunction()``
  /// to run the exit test. Running the exit test will always terminate the
  /// current process.
  fileprivate var body: @Sendable () async throws -> Void = {}

  /// Storage for ``observedValues``.
  ///
  /// Key paths are not sendable because the properties they refer to may or may
  /// not be, so this property needs to be `nonisolated(unsafe)`. It is safe to
  /// use it in this fashion because ``ExitTest/Result`` is sendable.
  fileprivate var _observedValues = [any PartialKeyPath<ExitTest.Result> & Sendable]()

  /// Key paths representing results from within this exit test that should be
  /// observed and returned to the caller.
  ///
  /// The testing library sets this property to match what was passed by the
  /// developer to the `#expect(exitsWith:)` or `#require(exitsWith:)` macro.
  /// If you are implementing an exit test handler, you can check the value of
  /// this property to determine what information you need to preserve from your
  /// child process.
  ///
  /// The value of this property always includes ``ExitTest/Result/statusAtExit``
  /// even if the test author does not specify it.
  ///
  /// Within a child process running an exit test, the value of this property is
  /// otherwise unspecified.
  @_spi(ForToolsIntegrationOnly)
  public var observedValues: [any PartialKeyPath<ExitTest.Result> & Sendable] {
    get {
      var result = _observedValues
      if !result.contains(\.statusAtExit) { // O(n), but n <= 3 (no Set needed)
        result.append(\.statusAtExit)
      }
      return result
    }
    set {
      _observedValues = newValue
    }
  }
}

#if !SWT_NO_EXIT_TESTS
// MARK: - Current

@_spi(Experimental)
extension ExitTest {
  /// A container type to hold the current exit test.
  ///
  /// This class is temporarily necessary until `ManagedBuffer` is updated to
  /// support storing move-only values. For more information, see [SE-NNNN](https://github.com/swiftlang/swift-evolution/pull/2657).
  private final class _CurrentContainer: Sendable {
    /// The exit test represented by this container.
    ///
    /// The value of this property must be optional to avoid a copy when reading
    /// the value in ``ExitTest/current``.
    let exitTest: ExitTest?

    init(exitTest: borrowing ExitTest) {
      self.exitTest = ExitTest(id: exitTest.id, body: exitTest.body, _observedValues: exitTest._observedValues)
    }
  }

  /// Storage for ``current``.
  private static let _current = Locked<_CurrentContainer?>()

  /// The exit test that is running in the current process, if any.
  ///
  /// If the current process was created to run an exit test, the value of this
  /// property describes that exit test. If this process is the parent process
  /// of an exit test, or if no exit test is currently running, the value of
  /// this property is `nil`.
  ///
  /// The value of this property is constant across all tasks in the current
  /// process.
  public static var current: ExitTest? {
    _read {
      if let current = _current.rawValue {
        yield current.exitTest
      } else {
        yield nil
      }
    }
  }
}

// MARK: - Invocation

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension ExitTest {
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
#elseif os(Linux)
    // On Linux, disable the generation of core files. They may or may not be
    // disabled by default; if they are enabled, they significantly slow down
    // the performance of exit tests. The kernel special-cases RLIMIT_CORE=1 to
    // mean core files should not be generated even if they are being written to
    // a pipe instead of a regular file; that gets us our performance back.
    // SEE: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/fs/coredump.c#n610
    var rl = rlimit(rlim_cur: 1, rlim_max: 1)
    _ = setrlimit(CInt(RLIMIT_CORE.rawValue), &rl)
#elseif os(FreeBSD) || os(OpenBSD)
    // As with Linux, disable the generation core files. The BSDs do not, as far
    // as I can tell, special-case RLIMIT_CORE=1.
    var rl = rlimit(rlim_cur: 0, rlim_max: 0)
    _ = setrlimit(RLIMIT_CORE, &rl)
#elseif os(Windows)
    // On Windows, similarly disable Windows Error Reporting and the Windows
    // Error Reporting UI. Note we expect to be the first component to call
    // these functions, so we don't attempt to preserve any previously-set bits.
    _ = SetErrorMode(UINT(SEM_NOGPFAULTERRORBOX))
    _ = WerSetFlags(DWORD(WER_FAULT_REPORTING_NO_UI))
#else
#warning("Platform-specific implementation missing: unable to disable crash reporting")
#endif
  }

  /// Call the exit test in the current process.
  ///
  /// This function invokes the closure originally passed to
  /// `#expect(exitsWith:)` _in the current process_. That closure is expected
  /// to terminate the process; if it does not, the testing library will
  /// terminate the process as if its `main()` function returned naturally.
  public consuming func callAsFunction() async -> Never {
    Self._disableCrashReporting()

#if os(Windows)
    // Windows does not support signal handling to the degree UNIX-like systems
    // do. When a signal is raised in a Windows process, the default signal
    // handler simply calls `exit()` and passes the constant value `3`. To allow
    // us to handle signals on Windows, we install signal handlers for all
    // signals supported on Windows. These signal handlers exit with a specific
    // exit code that is unlikely to be encountered "in the wild" and which
    // encodes the caught signal. Corresponding code in the parent process looks
    // for these special exit codes and translates them back to signals.
    for sig in [SIGINT, SIGILL, SIGFPE, SIGSEGV, SIGTERM, SIGBREAK, SIGABRT] {
      _ = signal(sig) { sig in
        _Exit(STATUS_SIGNAL_CAUGHT_BITS | sig)
      }
    }
#endif

#if os(OpenBSD)
    // OpenBSD does not have posix_spawn_file_actions_addclosefrom_np().
    // However, it does have closefrom(2), which we call here as a best effort.
    if let from = Environment.variable(named: "SWT_CLOSEFROM").flatMap(CInt.init) {
      _ = closefrom(from)
    }
#endif

    // Set ExitTest.current before the test body runs.
    Self._current.withLock { current in
      current = _CurrentContainer(exitTest: self)
    }

    do {
      try await body()
    } catch {
      _errorInMain(error)
    }

    // If we get to this point without terminating, then we simulate main()'s
    // behavior which is to exit with EXIT_SUCCESS.
    exit(EXIT_SUCCESS)
  }
}

// MARK: - Discovery

extension ExitTest: DiscoverableAsTestContent {
  static var testContentKind: UInt32 {
    0x65786974
  }

  typealias TestContentAccessorHint = ID

  /// Store the test generator function into the given memory.
  ///
  /// - Parameters:
  ///   - outValue: The uninitialized memory to store the exit test into.
  ///   - id: The unique identifier of the exit test to store.
  ///   - body: The body closure of the exit test to store.
  ///   - typeAddress: A pointer to the expected type of the exit test as passed
  ///     to the test content record calling this function.
  ///   - hintAddress: A pointer to an instance of ``ID`` to use as a hint.
  ///
  /// - Returns: Whether or not an exit test was stored into `outValue`.
  ///
  /// - Warning: This function is used to implement the `#expect(exitsWith:)`
  ///   macro. Do not use it directly.
  public static func __store(
    _ id: (UInt64, UInt64),
    _ body: @escaping @Sendable () async throws -> Void,
    into outValue: UnsafeMutableRawPointer,
    asTypeAt typeAddress: UnsafeRawPointer,
    withHintAt hintAddress: UnsafeRawPointer? = nil
  ) -> CBool {
    let callerExpectedType = TypeInfo(describing: typeAddress.load(as: Any.Type.self))
    let selfType = TypeInfo(describing: Self.self)
    guard callerExpectedType == selfType else {
      return false
    }
    let id = ID(id)
    if let hintedID = hintAddress?.load(as: ID.self), hintedID != id {
      return false
    }
    outValue.initializeMemory(as: Self.self, to: Self(id: id, body: body))
    return true
  }
}

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension ExitTest {
  /// Find the exit test function at the given source location.
  ///
  /// - Parameters:
  ///   - id: The unique identifier of the exit test to find.
  ///
  /// - Returns: The specified exit test function, or `nil` if no such exit test
  ///   could be found.
  public static func find(identifiedBy id: ExitTest.ID) -> Self? {
    for record in Self.allTestContentRecords() {
      if let exitTest = record.load(withHint: id) {
        return exitTest
      }
    }

#if !SWT_NO_LEGACY_TEST_DISCOVERY
    // Call the legacy lookup function that discovers tests embedded in types.
    return types(withNamesContaining: exitTestContainerTypeNameMagic).lazy
      .compactMap { $0 as? any __ExitTestContainer.Type }
      .first { ID($0.__id) == id }
      .map { ExitTest(id: ID($0.__id), body: $0.__body) }
#else
    return nil
#endif
  }
}

// MARK: -

/// Check that an expression always exits (terminates the current process) with
/// a given status.
///
/// - Parameters:
///   - exitTestID: The unique identifier of the exit test.
///   - expectedExitCondition: The expected exit condition.
///   - observedValues: An array of key paths representing results from within
///     the exit test that should be observed and returned by this macro. The
///     ``ExitTest/Result/statusAtExit`` property is always returned.
///   - expression: The expression, corresponding to `condition`, that is being
///     evaluated (if available at compile time.)
///   - comments: An array of comments describing the expectation. This array
///     may be empty.
///   - isRequired: Whether or not the expectation is required. The value of
///     this argument does not affect whether or not an error is thrown on
///     failure.
///   - isolation: The actor to which the exit test is isolated, if any.
///   - sourceLocation: The source location of the expectation.
///
/// This function contains the common implementation for all
/// `await #expect(exitsWith:) { }` invocations regardless of calling
/// convention.
func callExitTest(
  identifiedBy exitTestID: (UInt64, UInt64),
  exitsWith expectedExitCondition: ExitTest.Condition,
  observing observedValues: [any PartialKeyPath<ExitTest.Result> & Sendable],
  expression: __Expression,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation
) async -> Result<ExitTest.Result?, any Error> {
  guard let configuration = Configuration.current ?? Configuration.all.first else {
    preconditionFailure("A test must be running on the current task to use #expect(exitsWith:).")
  }

  var result: ExitTest.Result
  do {
    var exitTest = ExitTest(id: ExitTest.ID(exitTestID))
    exitTest.observedValues = observedValues
    result = try await configuration.exitTestHandler(exitTest)

#if os(Windows)
    // For an explanation of this magic, see the corresponding logic in
    // ExitTest.callAsFunction().
    if case let .exitCode(exitCode) = result.statusAtExit, (exitCode & ~STATUS_CODE_MASK) == STATUS_SIGNAL_CAUGHT_BITS {
      result.statusAtExit = .signal(exitCode & STATUS_CODE_MASK)
    }
#endif
  } catch {
    // An error here would indicate a problem in the exit test handler such as a
    // failure to find the process' path, to construct arguments to the
    // subprocess, or to spawn the subprocess. Such failures are system issues,
    // not test issues, because they constitute failures of the test
    // infrastructure rather than the test itself.
    //
    // But here's a philosophical question: should the exit test also fail with
    // an expectation failure? Arguably no, because the issue is a systemic one
    // and (presumably) not a bug in the test. But also arguably yes, because
    // the exit test did not do what the test author expected it to do.
    let backtrace = Backtrace(forFirstThrowOf: error) ?? .current()
    let issue = Issue(
      kind: .system,
      comments: comments() + CollectionOfOne(Comment(rawValue: String(describingForTest: error))),
      sourceContext: SourceContext(backtrace: backtrace, sourceLocation: sourceLocation)
    )
    issue.record(configuration: configuration)

    // For lack of a better way to handle an exit test failing in this way,
    // we record the system issue above, then let the expectation fail below by
    // reporting an exit condition that's the inverse of the expected one.
    let statusAtExit: StatusAtExit = if expectedExitCondition.isApproximatelyEqual(to: .exitCode(EXIT_FAILURE)) {
      .exitCode(EXIT_SUCCESS)
    } else {
      .exitCode(EXIT_FAILURE)
    }
    result = ExitTest.Result(statusAtExit: statusAtExit)
  }

  // How did the exit test actually exit?
  let actualStatusAtExit = result.statusAtExit

  // Plumb the exit test's result through the general expectation machinery.
  return __checkValue(
    expectedExitCondition.isApproximatelyEqual(to: actualStatusAtExit),
    expression: expression,
    expressionWithCapturedRuntimeValues: expression.capturingRuntimeValues(actualStatusAtExit),
    mismatchedExitConditionDescription: String(describingForTest: expectedExitCondition),
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  ).map { result }
}

// MARK: - SwiftPM/tools integration

extension ABI {
  /// The ABI version to use for encoding and decoding events sent over the back
  /// channel.
  ///
  /// The back channel always uses the latest ABI version (even if experimental)
  /// since both the producer and consumer use this exact version of the testing
  /// library.
  fileprivate typealias BackChannelVersion = v1
}

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension ExitTest {
  /// A handler that is invoked when an exit test starts.
  ///
  /// - Parameters:
  ///   - exitTest: The exit test that is starting.
  ///
  /// - Returns: The result of the exit test including the condition under which
  ///   it exited.
  ///
  /// - Throws: Any error that prevents the normal invocation or execution of
  ///   the exit test.
  ///
  /// This handler is invoked when an exit test (i.e. a call to either
  /// ``expect(exitsWith:observing:_:sourceLocation:performing:)`` or
  /// ``require(exitsWith:observing:_:sourceLocation:performing:)``) is started.
  /// The handler is responsible for initializing a new child environment
  /// (typically a child process) and running the exit test identified by
  /// `sourceLocation` there.
  ///
  /// In the child environment, you can find the exit test again by calling
  /// ``ExitTest/find(at:)`` and can run it by calling
  /// ``ExitTest/callAsFunction()``.
  ///
  /// The parent environment should suspend until the results of the exit test
  /// are available or the child environment is otherwise terminated. The parent
  /// environment is then responsible for interpreting those results and
  /// recording any issues that occur.
  public typealias Handler = @Sendable (_ exitTest: borrowing ExitTest) async throws -> ExitTest.Result

  /// The back channel file handle set up by the parent process.
  ///
  /// The value of this property is a file handle open for writing to which
  /// events should be written, or `nil` if the file handle could not be
  /// resolved.
  private static let _backChannelForEntryPoint: FileHandle? = {
    guard let backChannelEnvironmentVariable = Environment.variable(named: "SWT_EXPERIMENTAL_BACKCHANNEL") else {
      return nil
    }

    var fd: CInt?
#if SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD) || os(OpenBSD)
    fd = CInt(backChannelEnvironmentVariable)
#elseif os(Windows)
    if let handle = UInt(backChannelEnvironmentVariable).flatMap(HANDLE.init(bitPattern:)) {
      fd = _open_osfhandle(Int(bitPattern: handle), _O_WRONLY | _O_BINARY)
    }
#else
#warning("Platform-specific implementation missing: back-channel pipe unavailable")
#endif
    guard let fd, fd >= 0 else {
      return nil
    }

    return try? FileHandle(unsafePOSIXFileDescriptor: fd, mode: "wb")
  }()

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
    // Find the ID of the exit test to run, if any, in the environment block.
    var id: ExitTest.ID?
    if var idString = Environment.variable(named: "SWT_EXPERIMENTAL_EXIT_TEST_ID") {
      id = try? idString.withUTF8 { idBuffer in
        try JSON.decode(ExitTest.ID.self, from: UnsafeRawBufferPointer(idBuffer))
      }
    }
    guard let id else {
      return nil
    }

    // If an exit test was found, inject back channel handling into its body.
    // External tools authors should set up their own back channel mechanisms
    // and ensure they're installed before calling ExitTest.callAsFunction().
    guard var result = find(identifiedBy: id) else {
      return nil
    }

    // We can't say guard let here because it counts as a consume.
    guard _backChannelForEntryPoint != nil else {
      return result
    }

    // Set up the configuration for this process.
    var configuration = Configuration()

    // Encode events as JSON and write them to the back channel file handle.
    // Only forward issue-recorded events. (If we start handling other kinds of
    // events in the future, we can forward them too.)
    let eventHandler = ABI.BackChannelVersion.eventHandler(encodeAsJSONLines: true) { json in
      _ = try? _backChannelForEntryPoint?.withLock {
        try _backChannelForEntryPoint?.write(json)
        try _backChannelForEntryPoint?.write("\n")
      }
    }
    configuration.eventHandler = { event, eventContext in
      if case .issueRecorded = event.kind {
        eventHandler(event, eventContext)
      }
    }

    result.body = { [configuration, body = result.body] in
      try await Configuration.withCurrent(configuration, perform: body)
    }
    return result
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
    let childProcessExecutablePath = Swift.Result { try CommandLine.executablePath }

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
      try JSON.withEncoding(of: exitTest.id) { json in
        childEnvironment["SWT_EXPERIMENTAL_EXIT_TEST_ID"] = String(decoding: json, as: UTF8.self)
      }

      typealias ResultUpdater = @Sendable (inout ExitTest.Result) -> Void
      return try await withThrowingTaskGroup(of: ResultUpdater?.self) { taskGroup in
        // Set up stdout and stderr streams. By POSIX convention, stdin/stdout
        // are line-buffered by default and stderr is unbuffered by default.
        // SEE: https://en.cppreference.com/w/cpp/io/c/std_streams
        var stdoutReadEnd: FileHandle?
        var stdoutWriteEnd: FileHandle?
        if exitTest._observedValues.contains(\.standardOutputContent) {
          try FileHandle.makePipe(readEnd: &stdoutReadEnd, writeEnd: &stdoutWriteEnd)
          stdoutWriteEnd?.withUnsafeCFILEHandle { stdout in
            _ = setvbuf(stdout, nil, _IOLBF, Int(BUFSIZ))
          }
        }
        var stderrReadEnd: FileHandle?
        var stderrWriteEnd: FileHandle?
        if exitTest._observedValues.contains(\.standardErrorContent) {
          try FileHandle.makePipe(readEnd: &stderrReadEnd, writeEnd: &stderrWriteEnd)
          stderrWriteEnd?.withUnsafeCFILEHandle { stderr in
            _ = setvbuf(stderr, nil, _IONBF, Int(BUFSIZ))
          }
        }

        // Create a "back channel" pipe to handle events from the child process.
        var backChannelReadEnd: FileHandle!
        var backChannelWriteEnd: FileHandle!
        try FileHandle.makePipe(readEnd: &backChannelReadEnd, writeEnd: &backChannelWriteEnd)

        // Let the child process know how to find the back channel by setting a
        // known environment variable to the corresponding file descriptor
        // (HANDLE on Windows.)
        var backChannelEnvironmentVariable: String?
#if SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD) || os(OpenBSD)
        backChannelEnvironmentVariable = backChannelWriteEnd.withUnsafePOSIXFileDescriptor { fd in
          fd.map(String.init(describing:))
        }
#elseif os(Windows)
        backChannelEnvironmentVariable = backChannelWriteEnd.withUnsafeWindowsHANDLE { handle in
          handle.flatMap { String(describing: UInt(bitPattern: $0)) }
        }
#else
#warning("Platform-specific implementation missing: back-channel pipe unavailable")
#endif
        if let backChannelEnvironmentVariable {
          childEnvironment["SWT_EXPERIMENTAL_BACKCHANNEL"] = backChannelEnvironmentVariable
        }

        // Spawn the child process.
        let processID = try withUnsafePointer(to: backChannelWriteEnd) { backChannelWriteEnd in
          try spawnExecutable(
            atPath: childProcessExecutablePath,
            arguments: childArguments,
            environment: childEnvironment,
            standardOutput: stdoutWriteEnd,
            standardError: stderrWriteEnd,
            additionalFileHandles: [backChannelWriteEnd]
          )
        }

        // Await termination of the child process.
        taskGroup.addTask {
          let statusAtExit = try await wait(for: processID)
          return { $0.statusAtExit = statusAtExit }
        }

        // Read back the stdout and stderr streams.
        if let stdoutReadEnd {
          stdoutWriteEnd?.close()
          taskGroup.addTask {
            let standardOutputContent = try stdoutReadEnd.readToEnd()
            return { $0.standardOutputContent = standardOutputContent }
          }
        }
        if let stderrReadEnd {
          stderrWriteEnd?.close()
          taskGroup.addTask {
            let standardErrorContent = try stderrReadEnd.readToEnd()
            return { $0.standardErrorContent = standardErrorContent }
          }
        }

        // Read back all data written to the back channel by the child process
        // and process it as a (minimal) event stream.
        backChannelWriteEnd.close()
        taskGroup.addTask {
          Self._processRecords(fromBackChannel: backChannelReadEnd)
          return nil
        }

        // Collate the various bits of the result. The exit condition used here
        // is just a placeholder and will be replaced by the result of one of
        // the tasks above.
        var result = ExitTest.Result(statusAtExit: .exitCode(EXIT_FAILURE))
        for try await update in taskGroup {
          update?(&result)
        }
        return result
      }
    }
  }

  /// Read lines from the given back channel file handle and process them as
  /// event records.
  ///
  /// - Parameters:
  ///   - backChannel: The file handle to read from. Reading continues until an
  ///     error is encountered or the end of the file is reached.
  private static func _processRecords(fromBackChannel backChannel: borrowing FileHandle) {
    let bytes: [UInt8]
    do {
      bytes = try backChannel.readToEnd()
    } catch {
      // NOTE: an error caught here indicates an I/O problem.
      // TODO: should we record these issues as systemic instead?
      Issue(for: error).record()
      return
    }

    for recordJSON in bytes.split(whereSeparator: \.isASCIINewline) where !recordJSON.isEmpty {
      do {
        try recordJSON.withUnsafeBufferPointer { recordJSON in
          try Self._processRecord(.init(recordJSON), fromBackChannel: backChannel)
        }
      } catch {
        // NOTE: an error caught here indicates a decoding problem.
        // TODO: should we record these issues as systemic instead?
        Issue(for: error).record()
      }
    }
  }

  /// Decode a line of JSON read from a back channel file handle and handle it
  /// as if the corresponding event occurred locally.
  ///
  /// - Parameters:
  ///   - recordJSON: The JSON to decode and process.
  ///   - backChannel: The file handle that `recordJSON` was read from.
  ///
  /// - Throws: Any error encountered attempting to decode or process the JSON.
  private static func _processRecord(_ recordJSON: UnsafeRawBufferPointer, fromBackChannel backChannel: borrowing FileHandle) throws {
    let record = try JSON.decode(ABI.Record<ABI.BackChannelVersion>.self, from: recordJSON)

    if case let .event(event) = record.kind, let issue = event.issue {
      // Translate the issue back into a "real" issue and record it
      // in the parent process. This translation is, of course, lossy
      // due to the process boundary, but we make a best effort.
      let comments: [Comment] = event.messages.compactMap { message in
        message.symbol == .details ? Comment(rawValue: message.text) : nil
      }
      let issueKind: Issue.Kind = if let error = issue._error {
        .errorCaught(error)
      } else {
        // TODO: improve fidelity of issue kind reporting (especially those without associated values)
        .unconditional
      }
      let sourceContext = SourceContext(
        backtrace: nil, // `issue._backtrace` will have the wrong address space.
        sourceLocation: issue.sourceLocation
      )
      var issueCopy = Issue(kind: issueKind, comments: comments, sourceContext: sourceContext)
      issueCopy.isKnown = issue.isKnown
      issueCopy.record()
    }
  }
}
#endif
