//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !SWT_NO_EXIT_TESTS
internal import TestingInternals

#if SWT_TARGET_OS_APPLE || os(Linux)
/// Wait for a given PID to exit and report its status.
///
/// - Parameters:
///   - pid: The PID to wait for.
///
/// - Returns: The exit condition of `pid`.
///
/// - Throws: Any error encountered calling `waitpid()` except for `EINTR`,
///   which is ignored.
///
/// This function blocks the calling thread on `waitpid()`. External callers
/// should use ``wait(for:)`` instead to avoid deadlocks.
private func _blockAndWait(for pid: pid_t) throws -> ExitCondition {
  while true {
    var status: CInt = 0
    if waitpid(pid, &status, 0) >= 0 {
      if swt_WIFSIGNALED(status) {
        return .signal(swt_WTERMSIG(status))
      } else if swt_WIFEXITED(status) {
        return .exitCode(swt_WEXITSTATUS(status))
      } else {
        // Unreachable: neither signalled nor exited, but waitpid()
        // and libdispatch indicate that the process has died.
        throw SystemError(description: "Unexpected waitpid() result \(status). Please file a bug report at https://github.com/apple/swift-testing/issues/new")
      }
    } else if swt_errno() != EINTR {
      throw CError(rawValue: swt_errno())
    }
  }
}

/// Wait for a given PID to exit and report its status.
///
/// - Parameters:
///   - pid: The PID to wait for.
///
/// - Returns: The exit condition of `pid`.
///
/// - Throws: Any error encountered calling `waitpid()` except for `EINTR`,
///   which is ignored.
func wait(for pid: pid_t) async throws -> ExitCondition {
#if SWT_TARGET_OS_APPLE
  let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit)
  defer {
    source.cancel()
  }
  await withCheckedContinuation { continuation in
    source.setEventHandler {
      continuation.resume()
    }
    source.resume()
  }
  withExtendedLifetime(source) {}
  return try _blockAndWait(for: pid)
#else
  // On Linux, spin up a background thread and waitpid() there.
  return try await withCheckedThrowingContinuation { continuation in
    // Create a structure to hold the state needed by the thread, and box it
    // as a refcounted pointer that we can pass to libpthread.
    struct Context {
      var pid: pid_t
      var continuation: CheckedContinuation<ExitCondition, any Error>
    }
    let context = Unmanaged.passRetained(
      Context(pid: pid, continuation: continuation) as AnyObject
    ).toOpaque()

    // The body of the thread: unwrap and take ownership of the context we
    // created above, then call waitpid() and report the result/error.
    let body: @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? = { contextp in
      let context = Unmanaged<AnyObject>.fromOpaque(contextp!).takeRetainedValue() as! Context
      let result = Result { try _blockAndWait(for: context.pid) }
      context.continuation.resume(with: result)
      return nil
    }

    // Create the thread. We immediately detach it upon success to allow the
    // system to reclaim its resources when done.
    var thread = pthread_t()
    switch pthread_create(&thread, nil, body, context) {
    case 0:
      _ = pthread_detach(thread)
    case let errorCode:
      continuation.resume(throwing: CError(rawValue: errorCode))
    }
  }
#endif
}
#elseif os(Windows)
/// Wait for a given process handle to exit and report its status.
///
/// - Parameters:
///   - processHandle: The handle to wait for.
///
/// - Returns: The exit condition of `processHandle`.
///
/// - Throws: Any error encountered calling `WaitForSingleObject()` or
///   `GetExitCodeProcess()`.
///
/// This function blocks the calling thread on `WaitForSingleObject()`. External
/// callers should use ``wait(for:)`` instead to avoid deadlocks.
private func _blockAndWait(for processHandle: HANDLE) throws -> ExitCondition {
  if WAIT_FAILED == WaitForSingleObject(processHandle, INFINITE) {
    throw Win32Error(rawValue: GetLastError())
  }
  var status: DWORD = 0
  guard GetExitCodeProcess(processHandle, &status) else {
    // The child process terminated but we couldn't get its status back.
    // Assume generic failure.
    return .failure
  }

  // FIXME: handle SEH/VEH uncaught exceptions.
  return .exitCode(CInt(bitPattern: status))
}

/// Wait for a given process handle to exit and report its status.
///
/// - Parameters:
///   - processHandle: The handle to wait for.
///
/// - Returns: The exit condition of `processHandle`.
///
/// - Throws: Any error encountered calling `WaitForSingleObject()` or
///   `GetExitCodeProcess()`.
func wait(for processHandle: HANDLE) async throws -> ExitCondition {
  try await withCheckedThrowingContinuation { continuation in
    // Create a structure to hold the state needed by the thread, and box it
    // as a refcounted pointer that we can pass to libpthread.
    struct Context {
      var processHandle: HANDLE
      var continuation: CheckedContinuation<ExitCondition, any Error>
    }
    let context = Unmanaged.passRetained(
      Context(processHandle: processHandle, continuation: continuation) as AnyObject
    ).toOpaque()

    let body: _beginthread_proc_type = { contextp in
      let context = Unmanaged<AnyObject>.fromOpaque(contextp!).takeRetainedValue() as! Context
      let result = Result { try _blockAndWait(for: context.processHandle) }
      context.continuation.resume(with: result)
    }
    _ = _beginthread(body, 0, context)
  }
}
#endif
#endif
