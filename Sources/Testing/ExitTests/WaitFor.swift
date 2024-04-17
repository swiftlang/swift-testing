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

#if !(SWT_TARGET_OS_APPLE && !SWT_NO_LIBDISPATCH)
/// A mapping of awaited child PIDs to their corresponding Swift continuations.
private let _childProcessContinuations = Locked<[pid_t: CheckedContinuation<Void, Never>]>()

/// A condition variable used to suspend the waiter thread created by
/// `_createWaitThread()` when there are no child processes to await.
nonisolated(unsafe) private let _waitThreadNoChildrenCondition = {
  let result = UnsafeMutablePointer<pthread_cond_t>.allocate(capacity: 1)
  _ = pthread_cond_init(result, nil)
  return result
}()

#if os(Linux)
/// Set the name of the current thread.
///
/// This function declaration is provided because `pthread_setname_np()` is
/// only declared if `_GNU_SOURCE` is set, but setting it causes build errors
/// due to conflicts with Swift's Glibc module.
@_extern(c) func pthread_setname_np(_: pthread_t, _: UnsafePointer<CChar>) -> CInt
#endif

/// The implementation of `_createWaitThread()`, run only once.
private let _createWaitThreadImpl: Void = {
  // The body of the thread's run loop.
  func waitForAnyChild() {
    // Listen for child process exit events. WNOWAIT means we don't perturb the
    // state of a terminated (zombie) child process, allowing the corresponding
    // suspended process to call waitpid() later at its leisure.
    var siginfo = siginfo_t()
    if 0 == waitid(P_ALL, 0, &siginfo, WEXITED | WNOWAIT) {
      let pid = swt_siginfo_t_si_pid(&siginfo)
      if pid != 0 {
        let continuation = _childProcessContinuations.withLock { childProcessContinuations in
          childProcessContinuations.removeValue(forKey: pid)
        }
        continuation?.resume()
      }
    } else {
      // An error occurred while checking for child processes. Get the value of
      // errno outside the lock in case acquiring the lock perturbs it.
      let errorCode = swt_errno()
      _childProcessContinuations.withUnsafeUnderlyingLock { lock, childProcessContinuations in
        if errorCode == ECHILD && childProcessContinuations.isEmpty {
          // We got ECHILD and there are no continuations added right now. Wait
          // on our no-children condition variable until awoken by a
          // newly-scheduled waiter process. (If this condition is spuriously
          // woken, we'll just loop again, which is fine.)
          _ = pthread_cond_wait(_waitThreadNoChildrenCondition, lock)
        }
      }
    }
  }

  // Create the thread. We immediately detach it upon success to allow the
  // system to reclaim its resources when done.
#if SWT_TARGET_OS_APPLE
  var thread: pthread_t?
#else
  var thread = pthread_t()
#endif
  _ = pthread_create(
    &thread,
    nil,
    { _ in
      // Set the thread name to help with diagnostics.
      let threadName = "swift-testing exit test monitor"
#if SWT_TARGET_OS_APPLE
      _ = pthread_setname_np(threadName)
#else
      _ = pthread_setname_np(pthread_self(), threadName)
#endif

      // Run an infinite loop that waits for child processes to terminate and
      // captures their exit statuses.
      while true {
        waitForAnyChild()
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
#if SWT_TARGET_OS_APPLE && !SWT_NO_LIBDISPATCH
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
#else
  // Ensure the waiter thread is running.
  _createWaitThread()

  await withCheckedContinuation { continuation in
    _childProcessContinuations.withLock { childProcessContinuations in
      // We don't need to worry about a race condition here because waitid()
      // does not clear the wait/zombie state of the child process. If it sees
      // the child process has terminated and manages to acquire the lock before
      // we add this continuation to the dictionary, then it will simply loop
      // and report the status again.
      let oldContinuation = childProcessContinuations.updateValue(continuation, forKey: pid)
      assert(oldContinuation == nil, "Unexpected continuation found for PID \(pid). Please file a bug report at https://github.com/apple/swift-testing/issues/new")

      // Wake up the waiter thread if it is waiting for more child processes.
      _ = pthread_cond_signal(_waitThreadNoChildrenCondition)
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
