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

@c @implementation
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

#if !SWT_NO_ABI_JSON_SCHEMA
  JSON.embeddedFileDescriptor = Environment.variable(named: "SWT_EXPERIMENTAL_EMBEDDED_JSON_FD").flatMap(CInt.init(_:))
#endif
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
