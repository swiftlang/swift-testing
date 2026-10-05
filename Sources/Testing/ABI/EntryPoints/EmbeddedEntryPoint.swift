//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals

#if canImport(Synchronization)
internal import Synchronization
#endif

#if hasFeature(Embedded)
/// Keep the process running until all asynchronous work has completed.
///
/// This function is exported by the Concurrency module. We use it in Embedded
/// Swift because `_runAsyncMain()` is not available there.
@_silgen_name("swift_task_asyncMainDrainQueue")
private func _asyncMainDrainQueue() -> Never

/// Get the `argc` and `argv` arguments to `swift_testing_embeddedMain()`.
///
/// - Parameters:
///   - argc: The value of `argc` passed to `swift_testing_embeddedMain()`.
///   - argv: The value of `argv` passed to `swift_testing_embeddedMain()`.
///
/// - Returns: A structure containing `argc` and `argv`, or a structure
///   containing the result of calling `_swift_testing_getArgcArgv()` if those
///   arguments were invalid, or `nil` if they were invalid and the latter
///   function returned `false`.
private func _getArgcArgv(
  _ argc: CInt,
  _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>>?,
) -> swift_testing_argc_argv_t? {
  if argc > 0, let argv {
    return swift_testing_argc_argv_t(argc: argc, argv: argv)
  }

  var argcArgv = swift_testing_argc_argv_t()
  if _swift_testing_getArgcArgv(&argcArgv), argcArgv.argc > 0, argcArgv.argv != nil {
    return swift_testing_argc_argv_t(argc: argc, argv: argv)
  }

  return nil
}

#if !SWT_NO_ENVIRONMENT_VARIABLES
/// Get the `envp` argument to `swift_testing_embeddedMain()`.
///
/// - Parameters:
///   - envp: The value of `envp` passed to `swift_testing_embeddedMain()`.
///
/// - Returns: `envp`, or the result of `_swift_testing_getEnvironment()` if
///   `envp` was `nil`, or `nil` if it was `nil` and the latter function
///   returned `false`.
private func _getEnvironment(
  _ envp: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? {
  if let envp {
    return envp
  }

  var envp: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
  if _swift_testing_getEnvironment(&envp) {
    return envp
  }

  return nil
}
#endif

@c @implementation
public func swift_testing_embeddedMain(
  _ argc: CInt = 0,
  _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>>? = nil,
  _ envp: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = nil
) -> Never {
  let argcArgv = _getArgcArgv(argc, argv)
#if !SWT_NO_ENVIRONMENT_VARIABLES
  let envp = _getEnvironment(envp)
#else
  let envp: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = nil
#endif

  // We call `_swift_testing_init()` before setting the global storage for
  // `argv` and `envp` because, on some smaller systems, mutexes and atomics may
  // not be available without an initialization call (that the implementation of
  // `_swift_testing_init()` would need to call for us).
  //
  // We call _swift_testing_deinit() below rather than in the `exit()` wrapper
  // in EmbeddedPlatform.swift because, if we call `_swift_exit()` along some
  // other code path, it might not be one that started in this function.
  _swift_testing_init(argcArgv?.argc ?? 0, argcArgv?.argv, envp)

  if let argcArgv {
    CommandLine._argcArgv.withLock { $0 = argcArgv }
  }
  if let envp {
    _ = Environment._unsafeAddress.compareExchange(expected: nil, desired: envp, ordering: .sequentiallyConsistent)
  }

  _ = Task {
    let exitCode = await entryPoint(passing: nil, eventHandler: nil)
    _swift_testing_deinit(exitCode)
    exit(exitCode)
  }
  _asyncMainDrainQueue()
}

// MARK: - Argument storage

extension CommandLine {
  /// Storage for ``arguments``.
  ///
  /// This property is internally accessible due to language constraints. Do not
  /// use it directly outside this file. Use ``arguments`` instead.
  static let _argcArgv = Mutex(swift_testing_argc_argv_t())
}

#if !SWT_NO_ENVIRONMENT_VARIABLES
extension Environment {
  /// Storage for ``unsafeAddress``.
  ///
  /// This property is internally accessible due to language constraints. Do not
  /// use it directly outside this file. Use ``variable(named:)``,
  /// ``flag(named:)``, or ``get()`` instead.
  static nonisolated(unsafe) let _unsafeAddress = Atomic<UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>(nil)
}
#endif
#endif
