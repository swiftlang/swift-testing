//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

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
///
/// - Warning: This function's signature is subject to change. This function may
///   be removed in a future update.
@export(interface) @c
public func swift_testing_embeddedMain(_ argc: CInt, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>>) -> Never {
  let argv = (0 ..< argc).compactMap { String(validatingCString: argv[Int($0)]) }
  guard let args = try? parseCommandLineArguments(from: argv) else {
    exit(EXIT_FAILURE)
  }

  _ = Task.immediate {
    let exitCode = await entryPoint(passing: args, eventHandler: nil)
    exit(exitCode)
  }
  _asyncMainDrainQueue()
}

/// Begin running tests in Embedded Swift.
///
/// This overload of `swift_testing_embeddedMain()` derives its arguments from
/// the function `_swift_testing_getArgcArgv()` declared in the testing
/// library's Platform Abstraction Layer annex. If you already have values for
/// `argc` and `argv`, you can pass them directly to the other overload of this
/// function.
///
/// - Warning: This function's signature is subject to change. This function may
///   be removed in a future update.
public func swift_testing_embeddedMain() -> Never {
  var argc = CInt(0)
  var argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>>?
  guard _swift_testing_getArgcArgv(&argc, &argv), argc > 0, let argv else {
    return withUnsafeTemporaryAllocation(of: UnsafeMutablePointer<CChar>.self, capacity: 1) { argv in
      swift_testing_embeddedMain(0, argv.baseAddress!)
    }
  }
  return swift_testing_embeddedMain(argc, argv)
}
#endif
