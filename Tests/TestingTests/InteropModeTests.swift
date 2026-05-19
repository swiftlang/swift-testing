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

#if !SWT_NO_EXIT_TESTS && !SWT_NO_INTEROP
@Suite struct `Unit tests for interop mode selection` {
  @Test func `Installation not required if experimentalOptInKey not set`() async {
    await #expect(processExitsWith: .success) {
      Environment.setVariable("0", named: Interop.experimentalOptInKey)
      #expect(Interop.Mode.limited.requiresInstallation == false)
    }
  }

  @Test(arguments: Interop.Mode.allCases)
  func `Not-none interop modes require installation`(mode: Interop.Mode) async {
    await #expect(processExitsWith: .success) { [mode] in
      Environment.setVariable("1", named: Interop.experimentalOptInKey)
      switch mode {
      case .none:
        #expect(!mode.requiresInstallation)
      case .complete, .limited, .strict:
        #expect(mode.requiresInstallation)
      }
    }
  }

  @Test func `Default interop mode`() async {
    #expect(Interop.Mode.current == .limited)
  }

  /// Run this test case in a separate process via exit tests since we will
  /// be modifying the environment during the test.
  @Test(
    arguments: [
      // Standard mode names
      ("none" as String?, Interop.Mode.none),
      ("limited", .limited),
      ("complete", .complete),
      ("strict", .strict),

      // Unknown mode
      (nil, .limited),
      ("idk", .limited),

      // Case sensitivity
      ("None", .limited),
      ("Limited", .limited),
      ("Complete", .limited),
      ("Strict", .limited),
    ])
  func `Read interop modes from environment`(envValue: String?, expectedMode: Interop.Mode) async {
    await #expect(processExitsWith: .success) { [envValue, expectedMode] in
      Environment.setVariable(envValue, named: Interop.Mode.interopModeEnvKey)
      #expect(Interop.Mode.current == expectedMode)
    }
  }
}
#endif
