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

#if SWT_NO_LEAKS_CHECKING
@available(*, unavailable, message: "Leak checking is not supported on this platform.")
#endif
@_spi(Experimental)
@freestanding(expression) public macro expect(
  leaks: Bool,
  _ comment: @autoclosure () -> Comment? = nil,
  sourceLocation: SourceLocation = #_sourceLocation,
  performing expression: () async throws -> Void
) = #externalMacro(module: "TestingMacros", type: "ExpectMacro")

#if SWT_NO_LEAKS_CHECKING
@available(*, unavailable, message: "Leak checking is not supported on this platform.")
#endif
@_spi(Experimental)
@freestanding(expression) public macro require(
  leaks: Bool,
  _ comment: @autoclosure () -> Comment? = nil,
  sourceLocation: SourceLocation = #_sourceLocation,
  performing expression: () async throws -> Void
) = #externalMacro(module: "TestingMacros", type: "RequireMacro")

#if !SWT_NO_LEAKS_CHECKING
#if !os(Windows)
/// A type representing an error that occurred while invoking the `leaks` tool.
private struct _LeaksError: Error, RawRepresentable {
  var rawValue: CInt
}
#endif

public func __checkClosureCall(
  leaks: Bool,
  performing body: () async throws -> Void,
  expression: __Expression,
  comments: @autoclosure () -> [Comment],
  isRequired: Bool,
  sourceLocation: SourceLocation
) async rethrows -> Result<Void, any Error> {
  try await body()

  let leakDetected: Bool

#if os(Windows)
  leakDetected = 0 != _CrtDumpMemoryLeaks()
#else
  do {
    let arguments = ["\(getpid())", "-quiet"]
    let exitCondition = try await spawnAndWait(forExecutableAtPath: "/usr/bin/leaks", arguments: arguments, environment: [:])
    if case let .exitCode(exitCode) = exitCondition, exitCode > 1 {
      throw _LeaksError(rawValue: exitCode)
    }
    leakDetected = exitCondition.matches(.failure)
  } catch {
    // An error here would indicate a problem in the exit test handler such as a
    // failure to find the process' path, to construct arguments to the
    // subprocess, or to spawn the subprocess. These are not expected to be
    // common issues, however they would constitute a failure of the test
    // infrastructure rather than the test itself and perhaps should not cause
    // the test to terminate early.
    return .failure(error)
  }
#endif

  return __checkValue(
    leaks == leakDetected,
    expression: expression,
    comments: comments(),
    isRequired: isRequired,
    sourceLocation: sourceLocation
  )
}
#endif
