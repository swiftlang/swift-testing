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

  @Option(name: "--test-product-path")
  var testProductPaths: [String] = []

#if SWT_TARGET_OS_APPLE
  @Option(name: "--swiftpm-testing-helper-path")
  var _swiftPMTestingHelperPath: String?

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
#endif

  mutating func run() async throws {
#if SWT_TARGET_OS_APPLE
    let swiftPMTestingHelperPath = try swiftPMTestingHelperPath
#else
#endif
    let grommets: [any Grommet]
#if !SWT_NO_PROCESS_SPAWNING
    grommets = try testProductPaths.map { testProductPath in
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
#else
    grommets = []
#endif

    try await harnessEntryPoint(running: grommets) as Never
  }
}
