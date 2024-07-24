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

internal import _TestingInternals

#if SWT_TARGET_OS_APPLE || os(Linux)
/// Block the calling thread, wait for the target process to exit, and return
/// a value describing the conditions under which it exited.
///
/// - Parameters:
///   - pid: The ID of the process to wait for.
///
/// - Throws: If the exit status of the process with ID `pid` cannot be
///   determined (i.e. it does not represent an exit condition.)
private func _blockAndWait(for pid: pid_t) throws -> ExitCondition {
  // Get the exit status of the process or throw an error (other than EINTR.)
  while true {
    var siginfo = siginfo_t()
    if 0 == waitid(P_PID, id_t(pid), &siginfo, WEXITED) {
      switch siginfo.si_code {
      case .init(CLD_EXITED):
        return .exitCode(siginfo.si_status)
      case .init(CLD_KILLED), .init(CLD_DUMPED):
        return .signal(siginfo.si_status)
      default:
        throw SystemError(description: "Unexpected siginfo_t value. Please file a bug report at https://github.com/apple/swift-testing/issues/new and include this information: \(String(reflecting: siginfo))")
      }
    } else if case let errorCode = swt_errno(), errorCode != EINTR {
      throw CError(rawValue: errorCode)
    }
  }
}

#if !(SWT_TARGET_OS_APPLE && !SWT_NO_LIBDISPATCH)
/// A mapping of awaited child PIDs to their corresponding Swift continuations.
private let _childProcessContinuations = CustomLocked<[pid_t: CheckedContinuation<ExitCondition, any Error>], pthread_mutex_t>()

/// A condition variable used to suspend the waiter thread created by
/// `_createWaitThread()` when there are no child processes to await.
private nonisolated(unsafe) let _waitThreadNoChildrenCondition = {
  let result = UnsafeMutablePointer<pthread_cond_t>.allocate(capacity: 1)
  _ = pthread_cond_init(result, nil)
  return result
}()

/// The implementation of `_createWaitThread()`, run only once.
private let _createWaitThreadImpl: Void = {
  // The body of the thread's run loop.
  func waitForAnyChild() {
    // Listen for child process exit events. WNOWAIT means we don't perturb the
    // state of a terminated (zombie) child process, allowing us to fetch the
    // continuation (if available) before reaping.
    var siginfo = siginfo_t()
    if 0 == waitid(P_ALL, 0, &siginfo, WEXITED | WNOWAIT) {
      if case let pid = siginfo.si_pid, pid != 0 {
        let continuation = _childProcessContinuations.withLock { childProcessContinuations in
          childProcessContinuations.removeValue(forKey: pid)
        }

        // If we had a continuation for this PID, allow the process to be reaped
        // and pass the resulting exit condition back to the calling task. If
        // there is no continuation, then either it hasn't been stored yet or
        // this child process is not tracked by the waiter thread.
        if let continuation {
          let result = Result {
            try _blockAndWait(for: pid)
          }
          continuation.resume(with: result)
        }
      }
    } else if case let errorCode = swt_errno(), errorCode == ECHILD {
      // We got ECHILD. If there are no continuations added right now, we should
      // suspend this thread on the no-children condition until it's awoken by a
      // newly-scheduled waiter process. (If this condition is spuriously
      // woken, we'll just loop again, which is fine.) Note that we read errno
      // outside the lock in case acquiring the lock perturbs it.
      _childProcessContinuations.withUnsafeUnderlyingLock { lock, childProcessContinuations in
        if childProcessContinuations.isEmpty {
          _ = pthread_cond_wait(_waitThreadNoChildrenCondition, lock)
        }
      }
    }
  }

  // Create the thread. It will run immediately; because it runs in an infinite
  // loop, we aren't worried about detaching or joining it.
#if SWT_TARGET_OS_APPLE
  var thread: pthread_t?
#else
  var thread = pthread_t()
#endif
  _ = pthread_create(
    &thread,
    nil,
    { _ in
      // Set the thread name to help with diagnostics. Note that different
      // platforms support different thread name lengths. See MAXTHREADNAMESIZE
      // on Darwin and TASK_COMM_LEN on Linux.
#if SWT_TARGET_OS_APPLE
      _ = pthread_setname_np("Swift Testing exit test monitor")
#else
      _ = pthread_setname_np(pthread_self(), "SWT ExT monitor")
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

  return try _blockAndWait(for: pid)
#else
  // Ensure the waiter thread is running.
  _createWaitThread()

  return try await withCheckedThrowingContinuation { continuation in
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
