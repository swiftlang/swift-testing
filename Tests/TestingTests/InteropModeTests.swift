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
  @Test(arguments: Interop.Mode.allCases)
  func `Not-none interop modes require installation`(mode: Interop.Mode) {
    switch mode {
    case .none:
      #expect(!mode.requiresInstallation)
    case .complete, .limited, .strict:
      #expect(mode.requiresInstallation)
    }
  }

  @Test func `Default interop mode`() async {
    #expect(Interop.Mode.current == .complete)
  }

  /// Run this test case in a separate process via exit tests since we will
  /// be modifying the environment during the test.
  ///
  /// Ideally we'd run each value in a separate exit test, but that requires
  /// combining parameterized tests and exit tests which is currently unsupported.
  @Test func `Read interop modes from environment`() async {

    /// Set the interop env var to the provided value. If the value is `nil`,
    /// then the env var is unset.
    @Sendable func given(
      value: String?, expect expectedMode: Interop.Mode,
      sourceLocation: SourceLocation = #_sourceLocation
    ) {
      let key = "SWIFT_TESTING_XCTEST_INTEROP_MODE"
      Environment.setVariable(value, named: key)

      #expect(Interop.Mode._currentImpl() == expectedMode, sourceLocation: sourceLocation)
    }

    await #expect(processExitsWith: .success) {
      // Standard mode names
      given(value: "none", expect: .none)
      given(value: "limited", expect: .limited)
      given(value: "complete", expect: .complete)
      given(value: "strict", expect: .strict)

      let defaultMode = Interop.Mode.complete
      // Unknown or unset mode
      given(value: nil, expect: defaultMode)
      given(value: "idk", expect: defaultMode)

      // Case sensitivity
      given(value: "None", expect: defaultMode)
      given(value: "Limited", expect: defaultMode)
      given(value: "Complete", expect: defaultMode)
      given(value: "Strict", expect: defaultMode)
    }
  }
}
#endif
