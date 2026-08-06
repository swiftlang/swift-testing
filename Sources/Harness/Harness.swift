//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(ForToolsIntegrationOnly) private import Testing
private import ArgumentParser

/// The harness' main command (i.e. its entry point).
@main struct Harness: Sendable, AsyncParsableCommand {
  fileprivate static let configuration = CommandConfiguration(
    commandName: "swift-testing-harness"
  )

  mutating func run() async throws {
    throw ValidationError("This tool is currently unimplemented.")
  }
}
