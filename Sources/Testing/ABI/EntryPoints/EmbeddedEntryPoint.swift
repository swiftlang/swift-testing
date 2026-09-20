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
///   - argv: The command-line arguments passed to the process, as per C's
///     specification of `main()`.
///   - argc: The number of command-line arguments at `argv`, as per C's
///     specification of `main()`.
///
/// - Warning: This function's signature is subject to change. This function may
///   be removed in a future update.
@export(interface) @c
public func swift_testing_embeddedMain(_ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>>, _ argc: CInt) -> Never {
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
/// - Parameters:
///   - sourceLocation: The source location of the call to this function.
///
/// - Warning: This function's signature is subject to change. This function may
///   be removed in a future update.
public func swift_testing_embeddedMain(sourceLocation: SourceLocation = #Testing::sourceLocation) -> Never {
  sourceLocation.moduleName.withCString { programName in
    withUnsafeTemporaryAllocation(of: UnsafeMutablePointer<CChar>?.self, capacity: 2) { argv in
      argv[0] = UnsafeMutablePointer(mutating: programName)
      argv[1] = nil // The C standard requires a NULL pointer after `argv`.
      argv.withMemoryRebound(to: UnsafeMutablePointer<CChar>.self) { argv in
        swift_testing_embeddedMain(argv.baseAddress!, CInt(argv.count - 1))
      }
    }
  }
}
#endif
