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
struct Harness: Sendable {
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

#if !SWT_NO_FILE_IO
    // The paths to zero or more files containing event stream output, encoded
    // as JSON Lines, that this harness should decode and replay.
    result.append(.option("--event-stream-input-path"))
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

  /// The value of the `--verbosity` argument.
  ///
  /// The logic of this property is equivalent to that of the
  /// ``__CommandLineArguments_v0/verbosity`` property.
  var verbosity: Int {
    if _args.hasFlag(withLabel: "--very-verbose") || _args.hasFlag(withLabel: "--vv") {
      return 2
    } else if _args.hasFlag(withLabel: "--verbose") || _args.hasFlag(withLabel: "-v") {
      return 1
    } else if _args.hasFlag(withLabel: "--quiet") || _args.hasFlag(withLabel: "-q") {
      return -1
    }
    return 0
  }

  init(commandLineArguments args: [String] = CommandLine.arguments) throws {
    _args = try CommandLineArgumentList(
      parsing: args,
      describedBy: Self._commandLineArgumentDescriptors,
      describingUnrecognizedArgumentWith: { _ in .anonymous }
    )
  }

  mutating func run() async throws {
    var grommets = [any Grommet]()

#if !SWT_NO_PROCESS_SPAWNING
    // Gather up any test targets to run and create "local process" grommets for
    // each of them.
    let testProductPaths = _args.options(withLabel: "--test-product-path")
#if SWT_TARGET_OS_APPLE
    let swiftPMTestingHelperPath = try swiftPMTestingHelperPath
#endif
    grommets += try testProductPaths.map { testProductPath in
#if SWT_TARGET_OS_APPLE
      let testProductBundle = Bundle(path: testProductPath)
      guard let testProductBinaryPath = testProductBundle?.executablePath else {
        throw CocoaError(.fileReadNoSuchFile)
      }

      return LocalProcessGrommet(
        testProductBinaryPath: testProductBinaryPath,
        swiftPMTestingHelperPath: swiftPMTestingHelperPath
      )
#else
      return LocalProcessGrommet(testProductPath: testProductPath)
#endif
    }
#endif

#if !SWT_NO_FILE_IO
    // Also create grommets for each event stream file that should be read and
    // replayed.
    let eventStreamInputPaths = _args.options(withLabel: "--event-stream-input-path")
    grommets += try eventStreamInputPaths.map(FileGrommet.init(readingFromFileAtPath:))
#endif

    try await harnessEntryPoint(running: grommets, verbosity: verbosity) as Never
  }
}

// MARK: -

@main struct Main {
  static func main() async throws {
    var state = try Harness()
    try await state.run()
  }
}
