//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ForToolsIntegrationOnly) import Testing
import Foundation

/// The harness' main command (i.e. its entry point).
@main struct Main: Sendable {
  static func main() async throws {
    var main = try Main()
    try await main.run()
  }

  /// The command-line arguments that the harness handles either for its own
  /// purposes or on behalf of test libraries.
  private static var _commandLineArgumentDescriptors: [CommandLineArgumentList.Descriptor] {
    var result = [CommandLineArgumentList.Descriptor]()

#if !SWT_NO_PROCESS_SPAWNING
    // The paths to zero or more test products that this harness should run.
    //
    // On Apple platforms, these paths are to the `.xctest` bundles produced by
    // Xcode or Swift Package Manager. On other platforms, these paths are to
    // the test executables produced by Swift Package Manager.
    result.append(.option("--test-product-path"))

#if SWT_TARGET_OS_APPLE
    result.append(.option("--swiftpm-testing-helper-path"))
#endif
#endif


    result += [
      .flag("--parallel"), .flag("--no-parallel"),
      .option("--num-workers"),
    ]

#if !SWT_NO_FILE_IO
    // The paths to zero or more files containing event stream output, encoded
    // as JSON Lines, that this harness should decode and replay.
    result.append(.option("--event-stream-input-path"))

    // TODO: honor --configuration-path at this layer
    result += [
      .option("--configuration-path"), .option("--experimental-configuration-path"),
    ]

    // We forward events to the event stream specified by the caller.
    result += [
      .option("--event-stream-output-path"), .option("--experimental-event-stream-output"),
      .option("--event-stream-version"), .option("--experimental-event-stream-version"),
    ]

    result.append(.option("--xunit-output"))

    result += [
      .flag("--enable-swift-testing"), .flag("--disable-swift-testing"),
    ]
#endif

    return result
  }

  /// The parsed command-line arguments for the current process.
  private var _args: CommandLineArgumentList

  /// On Apple platforms, the path to the `swiftpm-testing-helper` tool.
  ///
  /// This tool is used to host tests written using Swift Testing. If the caller
  /// does not specify this path, one is constructed relative to the harness
  /// executable's path.
  var swiftPMTestingHelperPath: String {
    get throws {
      if let swiftPMTestingHelperPath = _args.option(withLabel: "--swiftpm-testing-helper-path") {
        return swiftPMTestingHelperPath
      }

      let executablePath = try CommandLine.executablePath
      let executableURL = URL(fileURLWithPath: executablePath, isDirectory: false)
      let swiftPMTestingHelperURL = executableURL
        .deletingLastPathComponent() // - progname
        .deletingLastPathComponent() // - "testing"
        .appendingPathComponent("pm", isDirectory: true)
        .appendingPathComponent("swiftpm-testing-helper", isDirectory: false)
      return swiftPMTestingHelperURL.path
    }
  }

  init(commandLineArguments args: [String] = CommandLine.arguments) throws {
    _args = try CommandLineArgumentList(
      parsing: args,
      describedBy: Self._commandLineArgumentDescriptors,
      describingUnrecognizedArgumentWith: { _ in .anonymous }
    )
  }

  /// Run the harness.
  mutating func run() async throws {
    var eventGenerators = [any Harness.EventGenerator]()

#if !SWT_NO_PROCESS_SPAWNING
    // Gather up any test targets to run and create "local process" generators
    // for each of them.
    let testProductPaths = _args.options(withLabel: "--test-product-path")
#if SWT_TARGET_OS_APPLE
    let swiftPMTestingHelperPath = try swiftPMTestingHelperPath
#endif
    var argsForLocalProcesses = _args
    argsForLocalProcesses.removeArguments(for: Self._commandLineArgumentDescriptors)

    // These arguments are used both by the harness and runner, so add them back.
    // TODO: make argument stripping more elegant
    if _args.hasFlag(withLabel: "--parallel") {
      argsForLocalProcesses.setFlag(true, forLabel: "--parallel")
    }
    if _args.hasFlag(withLabel: "--no-parallel") {
      argsForLocalProcesses.setFlag(true, forLabel: "--no-parallel")
    }

    if !_args.hasFlag(withLabel: "--disable-swift-testing") {
      eventGenerators += try testProductPaths.map { testProductPath in
#if SWT_TARGET_OS_APPLE
        let testProductBundle = Bundle(path: testProductPath)
        guard let testProductBinaryPath = testProductBundle?.executablePath else {
          throw CocoaError(.fileReadNoSuchFile)
        }

        return Harness.LocalProcessEventGenerator(
          testProductBinaryPath: testProductBinaryPath,
          swiftPMTestingHelperPath: swiftPMTestingHelperPath,
          commandLineArguments: argsForLocalProcesses.arguments
        )
#else
        return Harness.LocalProcessEventGenerator(
          testProductPath: testProductPath,
          commandLineArguments: argsForLocalProcesses.arguments
        )
#endif
      }
    }
#endif

#if !SWT_NO_FILE_IO
    // Also create generators for each event stream file that should be read and
    // replayed.
    let eventStreamInputPaths = _args.options(withLabel: "--event-stream-input-path")
    eventGenerators += try eventStreamInputPaths.map(Harness.JSONLinesFileEventGenerator.init(readingFromFileAtPath:))
#endif

    try await Harness.entryPoint(generatingEventsWith: eventGenerators, arguments: _args) as Never
  }
}
