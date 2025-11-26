//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) import Testing
@testable import _TestingInternals

@Suite("Coverage API Tests")
struct CoverageTests {
    @Test("Profile functions are callable")
    func profileFunctionsCallable() {
        // Reset counters - should not crash
        __llvm_profile_reset_counters()
        print("Reset counters: OK")

        // Set a temporary filename
        let filename = "/tmp/test-coverage-\(getpid()).profraw"
        filename.withCString { cString in
            __llvm_profile_set_filename(cString)
        }
        print("Set filename: \(filename)")

        // Write profile
        let result = __llvm_profile_write_file()
        print("Write result: \(result)")
        #expect(result == 0, "Profile write should succeed")
    }

    @Test("CoverageTrait availability detection")
    func coverageTraitAvailability() {
        print("CoverageTrait.isAvailable: \(CoverageTrait.isAvailable)")
        // Just verify it doesn't crash - actual value depends on how tests are run
    }
}

// MARK: - Example usage with CoverageTrait

/// Example code to demonstrate coverage measurement
private func exampleFunction(_ value: Int) -> String {
    if value > 0 {
        return "positive"
    } else if value < 0 {
        return "negative"
    } else {
        return "zero"
    }
}

@Suite("Coverage Trait Demo", .coverage(outputDirectory: "/tmp"))
struct CoverageTraitDemo {
    @Test("Positive path")
    func positiveValue() {
        #expect(exampleFunction(5) == "positive")
    }

    @Test("Negative path")
    func negativeValue() {
        #expect(exampleFunction(-3) == "negative")
    }

    @Test("Zero path")
    func zeroValue() {
        #expect(exampleFunction(0) == "zero")
    }
}
