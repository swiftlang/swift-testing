//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(ForToolsIntegrationOnly) import Testing

// NOTE: SwiftPMTests contains additional test coverage for the argument parser.

struct `CommandLineArgumentList Tests` {
  @Test func `Parse various arguments`() throws {
    let args = ["PROGNAME", "dostuff", "hereandthere", "--foo", "bar", "--foo=baz", "--quux", "123", "--grommet", "--widget", "/path/to/nowhere"]
    let list = try CommandLineArgumentList(
      parsing: args,
      describedBy: [
        .subcommand("dostuff"),
        .subcommand("hereandthere"),
        .option("--foo"),
        .option("--quux"),
        .flag("--grommet"),
        .flag("--widget"),
        .anonymous,
      ]
    )

    #expect(list.subcommandNames == ["dostuff", "hereandthere"])

    #expect(list.option(withLabel: "--foo") == "bar")
    #expect(list.options(withLabel: "--foo") == ["bar", "baz"])
    #expect(!list.hasFlag(withLabel: "--foo"))

    #expect(list.option(withLabel: "--quux") == "123")
    #expect(list.options(withLabel: "--quux") == ["123"])
    #expect(!list.hasFlag(withLabel: "--quux"))

    #expect(list.option(withLabel: "--grommet") == nil)
    #expect(list.hasFlag(withLabel: "--grommet"))
    #expect(list.option(withLabel: "--widget") == nil)
    #expect(list.hasFlag(withLabel: "--widget"))
  }

  @Test func `Error thrown for unrecognized option/flag`() throws {
    let args = ["PROGNAME", "--foo", "--bar", "123", "--unexpected"]
    #expect(throws: CommandLineArgumentList.ParseError.unexpectedArgument("--unexpected")) {
      _ = try CommandLineArgumentList(
        parsing: args,
        describedBy: [
          .flag("--foo"), .option("--bar"),
        ]
      )
    }
  }

  @Test func `Fallback closure called for unrecognized argument`() async throws {
    let args = ["PROGNAME", "hello", "world", "--foo", "--bar", "123", "456"]
    try await confirmation("Called closure", expectedCount: args.count - 1) { confirmation in
      _ = try CommandLineArgumentList(
        parsing: args,
        describedBy: [],
        describingUnrecognizedArgumentWith: { _ in
          confirmation()
          return .anonymous
        }
      )
    }
  }
}
