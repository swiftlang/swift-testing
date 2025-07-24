//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Testing
import Foundation

@Suite("Hierarchical Output Demo - Progress Bar Test")
struct HierarchicalOutputDemo {

    @Test("Slow Test 1")
    func slowTest1() async throws {
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        #expect(1 + 1 == 2)
    }

    @Test("Slow Test 2")  
    func slowTest2() async throws {
        try await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
        #expect(2 + 2 == 4)
    }

    @Test("Slow Test 3")
    func slowTest3() async throws {
        try await Task.sleep(nanoseconds: 1_800_000_000) // 1.8 seconds
        #expect(3 + 3 == 6)
    }

    @Test("Slow Test 4")
    func slowTest4() async throws {
        try await Task.sleep(nanoseconds: 2_200_000_000) // 2.2 seconds
        #expect(4 + 4 == 8)
    }

    @Test("Slow Test 5")
    func slowTest5() async throws {
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        #expect(5 + 5 == 10)
    }
} 