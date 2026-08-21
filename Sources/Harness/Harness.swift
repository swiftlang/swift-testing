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
import ArgumentParser
import Foundation

/// The harness' main command (i.e. its entry point).
@main struct Harness: Sendable, AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swift-testing-harness"
  )

#if !SWT_NO_PROCESS_SPAWNING
  /// The paths to zero or more test products that this harness should run.
  ///
  /// On Apple platforms, these paths are to the `.xctest` bundles produced by
  /// Xcode or Swift Package Manager. On other platforms, these paths are to the
  /// test executables produced by Swift Package Manager.
  @Option(name: "--test-product-path")
  var testProductPaths: [String] = []

#if SWT_TARGET_OS_APPLE
  // TODO: derive these paths from toolchain root or some such?

  /// Storage for ``swiftPMTestingHelperPath``.
  @Option(name: "--swiftpm-testing-helper-path")
  private var _swiftPMTestingHelperPath: String?

  /// On Apple platforms, the path to the `swiftpm-testing-helper` tool.
  ///
  /// This tool is used to host tests written using Swift Testing. If the caller
  /// does not specify this path, one is constructed relative to the harness
  /// executable's path.
  var swiftPMTestingHelperPath: String {
    get throws {
      if let swiftPMTestingHelperPath = _swiftPMTestingHelperPath {
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

  /// Storage for ``xctestToolPath``.
  @Option(name: "--xctest-tool-path")
  private var _xctestToolPath: String?

  /// On Apple platforms, the path to the `xctest` tool.
  ///
  /// This tool is used to host tests written using XCTest. If the caller does
  /// not specify this path, one is constructed relative to the harness
  /// executable's path.
  var xctestToolPath: String {
    get throws {
      if let xctestToolPath = _xctestToolPath {
        return xctestToolPath
      }
      throw ValidationError("Could not find the 'xctest' tool.")
    }
  }
#endif
#endif

  /// The value of the `--verbose` argument.
  @Flag var verbose = false

  /// The value of the `--very-verbose` argument.
  @Flag var veryVerbose = false

  /// The value of the `--quiet` argument.
  @Flag var quiet = false

  /// The value of the `--verbosity` argument.
  ///
  /// The logic of this property is equivalent to that of the
  /// ``__CommandLineArguments_v0/verbosity`` property.
  var verbosity: Int {
    if veryVerbose {
      return 2
    } else if verbose {
      return 1
    } else if quiet {
      return -1
    }
    return 0
  }

#if !SWT_NO_FILE_IO
  /// The paths to zero or more files containing event stream output, encoded as
  /// [JSON Lines](https://jsonlines.org), that this harness should decode and
  /// replay.
  @Option(name: "--event-stream-input-path")
  var eventStreamInputPaths: [String] = []
#endif

  mutating func run() async throws {
    var grommets = [any Grommet]()

#if !SWT_NO_PROCESS_SPAWNING
    // Gather up any test targets to run and create "local process" grommets for
    // each of them.
#if SWT_TARGET_OS_APPLE
    let swiftPMTestingHelperPath = try swiftPMTestingHelperPath
    let xctestToolPath = try xctestToolPath
#endif
    grommets += try testProductPaths.flatMap { testProductPath -> [any Grommet] in
#if SWT_TARGET_OS_APPLE
      let testProductBundle = Bundle(path: testProductPath)
      guard let testProductBinaryPath = testProductBundle?.executablePath else {
        throw CocoaError(.fileReadNoSuchFile)
      }

      return [
        XCTestGrommet(
          testProductPath: testProductPath,
          xctestToolPath: xctestToolPath
        ),
        LocalProcessGrommet(
          testProductBinaryPath: testProductBinaryPath,
          swiftPMTestingHelperPath: swiftPMTestingHelperPath
        ),
      ]
#else
      return [
        XCTestGrommet(testProductPath: testProductPath),
        LocalProcessGrommet(testProductPath: testProductPath),
      ]
#endif
    }
#endif

#if !SWT_NO_FILE_IO
    // Also create grommets for each event stream file that should be read and
    // replayed.
    grommets += try eventStreamInputPaths.map(FileGrommet.init(readingFromFileAtPath:))
#endif

    try await harnessEntryPoint(running: grommets, verbosity: verbosity) as Never
  }
}
