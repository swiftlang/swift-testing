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

#if os(Linux)
/// A mapping of awaited child PIDs to their corresponding Swift continuations.
private let _childProcessContinuations = Locked<[pid_t: CheckedContinuation<Void, any Error>]>()

/// The implementation of `_createWaitThread()`, run only once.
private let _createWaitThreadImpl: Void = {
  // Create the thread. We immediately detach it upon success to allow the
  // system to reclaim its resources when done.

  var thread = pthread_t()
  _ = pthread_create(
    &thread,
    nil,
    { _ in
      // Run an infinite loop that waits for child processes to terminate and
      // captures their exit statuses.
      while true {
        var siginfo = siginfo_t()
        if 0 == waitid(P_ALL, 0, &siginfo, WEXITED | WNOWAIT) {
          let pid = swt_siginfo_t_si_pid(&siginfo)
          let continuation = _childProcessContinuations.withLock { childProcessContinuations in
            childProcessContinuations.removeValue(forKey: pid)
          }
          continuation?.resume()
        }
      }
    },
    nil
  )
}()

/// Create a waiter thread that is responsible for waiting for child processes
/// to exit.
private func _createWaitThread() {
  _createWaitThreadImpl
}
#endif

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
#elseif os(Linux)
  // Ensure the waiter thread is running.
  _createWaitThread()

  try await withCheckedThrowingContinuation { continuation in
    _childProcessContinuations.withLock { childProcessContinuations in
      // To avoid a race with the call to waitid(P_ALL) above, call waitid()
      // while holding this lock. If the process has already exited, then we
      // don't need to suspend and can immediately resume the continuation. If
      // the process has not exited, then the other call to waitid() cannot fire
      // and acquire the lock until after we've added the continuation.
      var siginfo = siginfo_t()
      if 0 == waitid(P_PID, .init(bitPattern: pid), &siginfo, WEXITED | WNOHANG | WNOWAIT) {
        if swt_siginfo_t_si_pid(&siginfo) == 0 {
          // No PID matched the waitid() call, i.e. `pid` is still running.
          let oldContinuation = childProcessContinuations.updateValue(continuation, forKey: pid)
          assert(oldContinuation == nil, "Unexpected continuation found for PID \(pid). Please file a bug report at https://github.com/apple/swift-testing/issues/new")
        } else {
          // waitid() reports that the PID has exited, so no continuation needs to
          // be stored and we can return immediately.
          continuation.resume()
        }
      } else {
        continuation.resume(throwing: CError(rawValue: swt_errno()))
      }
    }
  }
#endif
  return try _blockAndWait(for: pid)
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
func wait(for processHandle: HANDLE) async throws -> ExitCondition {
  // Once the continuation resumes, it will need to unregister the wait, so
  // yield the wait handle back to the calling scope.
  var waitHandle: HANDLE?
  defer {
    if let waitHandle {
      _ = UnregisterWait(waitHandle)
    }
  }

  try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
    // Set up a callback that immediately resumes the continuation and does no
    // other work.
    let context = Unmanaged.passRetained(continuation as AnyObject).toOpaque()
    let callback: WAITORTIMERCALLBACK = { context, _ in
      let continuation = Unmanaged<AnyObject>.fromOpaque(context!).takeRetainedValue() as! CheckedContinuation<Void, any Error>
      continuation.resume()
    }

    // We only want the callback to fire once (and not be rescheduled.) Waiting
    // may take an arbitrarily long time, so let the thread pool know that too.
    let flags = ULONG(WT_EXECUTEONLYONCE | WT_EXECUTELONGFUNCTION)
    guard RegisterWaitForSingleObject(&waitHandle, processHandle, callback, context, INFINITE, flags) else {
      continuation.resume(throwing: Win32Error(rawValue: GetLastError()))
      return
    }
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
#endif
#endif
