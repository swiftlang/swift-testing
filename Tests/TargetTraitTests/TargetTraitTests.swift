//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) @testable import Testing

// NOTE: this test file is in its own target because it affects the global state
// of its test target (by applying target traits, of course.)

@Suite("TargetTrait Tests")
struct TargetTraitTests {
  @Test func wasTargetTraitApplied() throws {
    let test = try #require(Test.current)

    let targetTraits = test.traits.compactMap { $0 as? MyTargetTrait }
    #expect(!targetTraits.isEmpty)

    #expect(Configuration.current?.isParallelizationEnabled == false)

    #expect(test.tags.contains(.targetTraitTag))
  }
}

// MARK: - Fixtures

extension Tag {
  @Tag static var targetTraitTag: Self
}

#targetTraits(MyTargetTrait(), .serialized, .tags(.targetTraitTag))

struct MyTargetTrait: TestTrait, TargetTrait {
  var isRecursive: Bool {
    true
  }
}
