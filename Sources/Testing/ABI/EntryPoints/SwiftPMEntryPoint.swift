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

/// The exit code returned to Swift Package Manager by Swift Testing when no
/// tests matched the inputs specified by the developer (or, for the case of
/// `swift test list`, when no tests were found.)
///
/// Because Swift Package Manager does not directly link to the testing library,
/// it duplicates the definition of this constant in its own source. Any changes
/// to this constant in either package must be mirrored in the other.
///
/// Tools authors using the ABI entry point function can determine if no tests
/// matched the developer's inputs by counting the number of test records passed
/// to the event handler or written to the event stream output path.
///
/// This constant is not part of the public interface of the testing library.
var EXIT_NO_TESTS_FOUND: CInt {
#if SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android) || os(WASI)
  EX_UNAVAILABLE
#elseif os(Windows)
  CInt(ERROR_NOT_FOUND)
#else
#warning("Platform-specific implementation missing: value for EXIT_NO_TESTS_FOUND unavailable")
  return 2 // We're assuming that EXIT_SUCCESS = 0 and EXIT_FAILURE = 1.
#endif
}

/// The entry point to the testing library used by Swift Package Manager.
///
/// - Parameters:
///   - args: A previously-parsed command-line arguments structure to interpret.
///     If `nil`, a new instance is created from the command-line arguments to
///     the current process.
///
/// - Returns: The result of invoking the testing library. The type of this
///   value is subject to change.
///
/// This function examines the command-line arguments represented by `args` and
/// then invokes available tests in the current process.
///
/// - Warning: This function is used by Swift Package Manager. Do not call it
///   directly.
public func __swiftPMEntryPoint(passing args: __CommandLineArguments_v0? = nil) async -> CInt {
#if !SWT_NO_FILE_IO
  // Ensure that stdout is line- rather than block-buffered. Swift Package
  // Manager reroutes standard I/O through pipes, so we tend to end up with
  // block-buffered streams.
  FileHandle.stdout.withUnsafeCFILEHandle { stdout in
    _ = setvbuf(stdout, nil, _IOLBF, Int(BUFSIZ))
  }
#endif

  // FIXME: this is probably the wrong layering for this check
  if let args = try? args ?? parseCommandLineArguments(from: CommandLine.arguments),
     let libraryName = args.testingLibrary,
     let library = Library(named: libraryName) {
    return await library.callEntryPoint(passing: args)
  }

  return await entryPoint(passing: args, eventHandler: nil)
}

/// The entry point to the testing library used by Swift Package Manager.
///
/// - Parameters:
///   - args: A previously-parsed command-line arguments structure to interpret.
///     If `nil`, a new instance is created from the command-line arguments to
///     the current process.
///
/// This function examines the command-line arguments to the current process
/// and then invokes available tests in the current process. When the tests
/// complete, the process is terminated. If tests were successful, an exit code
/// of `EXIT_SUCCESS` is used; otherwise, a (possibly platform-specific) value
/// such as `EXIT_FAILURE` is used instead.
///
/// - Warning: This function is used by Swift Package Manager. Do not call it
///   directly.
public func __swiftPMEntryPoint(passing args: __CommandLineArguments_v0? = nil) async -> Never {
  let exitCode: CInt = await __swiftPMEntryPoint(passing: args)
  exit(exitCode)
}
