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

/// The common implementation of `swift_testing_embeddedMain()`.
///
/// - Parameters:
///   - args: The command-line arguments passed to the process.
private func _swift_testing_embeddedMain(_ args: [String]) -> Never {
  guard let args = try? parseCommandLineArguments(from: args) else {
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
///   - argc: The number of command-line arguments at `argv`, as per C's
///     specification of `main()`.
///   - argv: The command-line arguments passed to the process, as per C's
///     specification of `main()`.
///
/// - Warning: This function's signature is subject to change. This function may
///   be removed in a future update.
@export(interface) @c
public func swift_testing_embeddedMain(_ argc: CInt, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>>) -> Never {
  let args = (0 ..< argc).compactMap { String(validatingCString: argv[Int($0)]) }
  _swift_testing_embeddedMain(args)
}

/// Begin running tests in Embedded Swift.
///
/// - Parameters:
///   - sourceLocation: The source location of the call to this function.
///
/// - Warning: This function's signature is subject to change. This function may
///   be removed in a future update.
public func swift_testing_embeddedMain(sourceLocation: SourceLocation = #Testing::sourceLocation) -> Never {
  CommandLine.defaultProgramName = sourceLocation.moduleName
  _swift_testing_embeddedMain(CommandLine.arguments)
}
#endif
