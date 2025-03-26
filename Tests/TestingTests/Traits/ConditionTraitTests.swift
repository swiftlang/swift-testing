//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable import Testing

@Suite("Condition Trait Tests", .tags(.traitRelated))
struct ConditionTraitTests {
  #if compiler(>=6.1)
  @Test(
    ".enabled trait",
    .enabled { true },
    .bug("https://github.com/swiftlang/swift/issues/76409", "Verify the custom trait with closure causes @Test macro to fail is fixed")
  )
  func enabledTraitClosure() throws {}
  #endif

  @Test(
    ".enabled if trait",
    .enabled(if: true)
  )
  func enabledTraitIf() throws {}

  #if compiler(>=6.1)
  @Test(
    ".disabled trait",
    .disabled { false },
    .bug("https://github.com/swiftlang/swift/issues/76409", "Verify the custom trait with closure causes @Test macro to fail is fixed")
  )
  func disabledTraitClosure() throws {}
  #endif

  @Test(
    ".disabled if trait",
    .disabled(if: false)
  )
  func disabledTraitIf() throws {}
}
