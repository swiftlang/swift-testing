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

/// Begin running tests in Embedded Swift.
///
/// - Parameters:
///   - argc: The number of command-line arguments at `argv`, as per C's
///     specification of `main()`.
///   - argv: The command-line arguments passed to the process, as per C's
///     specification of `main()`.
///   - envp: The environment variables set in the process, laid out as per the
///     POSIX standard for the `environ` global variable.
///
/// ### Passing command-line arguments and environment variables
///
/// You can directly pass the `argc` and `argv` arguments from your C `main()`
/// function to this function. On many platforms, `main()` can be declared with
/// an additional `envp` argument representing the environment block, which you
/// can also pass.
///
/// Alternatively, the testing library can get the program's command-line
/// arguments or environment variables by calling functions from its Platform
/// Abstraction Layer annex instead:
///
/// - If `argc` is `0` or `argv` is `nil`, the testing library calls the
///   function `_swift_testing_getArgcArgv()` to get values for them.
/// - If `envp` is `nil`, the testing library calls the function
/// `_swift_testing_getEnvironment()` to get a value for it.
///
/// - Important: If not `nil`, `argv` and `envp` must remain valid for the
///   lifetime of the program.
///
/// - Warning: This function's signature is subject to change. This function may
///   be removed in a future update.
@export(interface) @c
public func swift_testing_embeddedMain(
  _ argc: CInt = 0,
  _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>>? = nil,
  _ envp: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = nil
) -> Never {
  if argc > 0, let argv {
    let argcArgv = swift_testing_argc_argv_t(argc: argc, argv: argv)
    CommandLine._argcArgv.withLock { $0 = argcArgv }
  } else {
    var argcArgv = swift_testing_argc_argv_t()
    if _swift_testing_getArgcArgv(&argcArgv), argcArgv.argc > 0, argcArgv.argv != nil {
      CommandLine._argcArgv.withLock { $0 = argcArgv }
    }
  }

#if !SWT_NO_ENVIRONMENT_VARIABLES
  if let envp {
    _ = Environment._unsafeAddress.compareExchange(expected: nil, desired: envp, ordering: .sequentiallyConsistent)
  } else {
    var envp: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
    if _swift_testing_getEnvironment(&envp), let envp {
      _ = Environment._unsafeAddress.compareExchange(expected: nil, desired: envp, ordering: .sequentiallyConsistent)
    }
  }
#endif

  _ = Task.immediate {
    let exitCode = await entryPoint(passing: nil, eventHandler: nil)
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
