//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals

// MARK: - Coverage Detection

/// Check if coverage instrumentation is enabled for this test run.
///
/// This is determined by checking for the presence of coverage-related
/// environment variables.
private let _coverageEnabled: Bool = {
    // Check for LLVM_PROFILE_FILE environment variable (set by swift test)
    Environment.variable(named: "LLVM_PROFILE_FILE") != nil
}()

/// Get the output directory for coverage files.
private let _coverageOutputDirectory: String = {
    if let dir = Environment.variable(named: "COVERAGE_OUTPUT_DIR") {
        return dir
    }
    if let cwd = swt_getEarlyCWD() {
        return String(cString: cwd)
    }
    return "."
}()

// MARK: - CoverageTrait

/// A trait that collects per-test code coverage.
///
/// When this trait is applied to a test or suite, each test case gets its own
/// coverage profile file, enabling analysis of which code paths each test
/// exercises.
///
/// - Important: This trait automatically enforces serialized execution because
///   LLVM profile counters are shared global state. Tests with this trait will
///   run serially regardless of other parallelization settings.
///
/// ## Usage
///
/// Apply to a single test:
///
/// ```swift
/// @Test(.coverage)
/// func testFeature() {
///     // Coverage is written to coverage-testFeature.profraw
/// }
/// ```
///
/// Apply to an entire suite:
///
/// ```swift
/// @Suite(.coverage)
/// struct MyTests {
///     @Test func test1() { ... }
///     @Test func test2() { ... }
/// }
/// ```
///
/// ## Requirements
///
/// Per-test coverage requires building and running tests with coverage enabled:
///
/// ```bash
/// swift test --enable-code-coverage
/// ```
///
/// ## Output
///
/// Coverage files are written to `$COVERAGE_OUTPUT_DIR` (or current directory):
///
/// - `coverage-testName.profraw` for each test
///
/// Merge and view results:
///
/// ```bash
/// xcrun llvm-profdata merge -sparse coverage-*.profraw -o merged.profdata
/// xcrun llvm-cov report .build/debug/TestBundle -instr-profile=merged.profdata
/// ```
@_spi(Experimental)
public struct CoverageTrait: TestTrait, SuiteTrait {
    /// Whether to reset coverage counters before each test.
    ///
    /// When `true` (default), each test's coverage file only contains the
    /// coverage from that specific test. When `false`, coverage accumulates
    /// across tests.
    public var isolatesTests: Bool

    /// The directory where coverage files are written.
    ///
    /// Defaults to `COVERAGE_OUTPUT_DIR` environment variable or current
    /// working directory.
    public var outputDirectory: String

    /// Create a coverage trait.
    ///
    /// - Parameters:
    ///   - isolatesTests: Whether to reset counters before each test.
    ///   - outputDirectory: Directory for coverage files.
    public init(
        isolatesTests: Bool = true,
        outputDirectory: String? = nil
    ) {
        self.isolatesTests = isolatesTests
        self.outputDirectory = outputDirectory ?? _coverageOutputDirectory
    }

    public var isRecursive: Bool { true }
}

// MARK: - TestScoping

extension CoverageTrait: TestScoping {
    public func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
        // When applied to a test function, provide scope to the test function
        // itself (not individual test cases) so we can disable parallelization
        // at the suite/function level.
        test.isSuite || testCase == nil ? self : nil
    }

    public func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        // Skip coverage collection if not enabled
        guard _coverageEnabled else {
            try await function()
            return
        }

        // Enforce serialization - coverage requires serial execution because
        // LLVM profile counters are shared global state across all threads.
        guard var configuration = Configuration.current else {
            try await function()
            return
        }
        configuration.isParallelizationEnabled = false

        try await Configuration.withCurrent(configuration) {
            // Reset counters to isolate this test's coverage
            if isolatesTests {
                __llvm_profile_reset_counters()
            }

            // Run the test
            do {
                try await function()
            } catch {
                // Write coverage even if test fails
                writeCoverage(for: test, testCase: testCase)
                throw error
            }

            // Write coverage for this test
            writeCoverage(for: test, testCase: testCase)
        }
    }

    private func writeCoverage(for test: Test, testCase: Test.Case?) {
        let filename = coverageFilename(for: test, testCase: testCase)

        filename.withCString { cString in
            __llvm_profile_set_filename(cString)
        }

        _ = __llvm_profile_write_file()
    }

    private func coverageFilename(for test: Test, testCase: Test.Case?) -> String {
        var name = test.name
        if let testCase {
            // Include test case ID for parameterized tests
            name += "-\(testCase.id)"
        }

        // Sanitize for filesystem - replace problematic characters
        var sanitized = ""
        for char in name {
            switch char {
            case "/", ":", " ", "(", ")", ",", "\\", "<", ">", "\"", "|", "?", "*":
                sanitized.append("_")
            default:
                sanitized.append(char)
            }
        }

        return "\(outputDirectory)/coverage-\(sanitized).profraw"
    }
}

// MARK: - Trait Extension

@_spi(Experimental)
extension Trait where Self == CoverageTrait {
    /// A trait that collects per-test code coverage.
    ///
    /// Apply this trait to tests or suites to generate individual coverage
    /// profiles for each test case.
    ///
    /// ```swift
    /// @Test(.coverage)
    /// func testFeature() { ... }
    /// ```
    public static var coverage: Self {
        Self()
    }

    /// A trait that collects per-test code coverage with custom options.
    ///
    /// - Parameters:
    ///   - isolatesTests: Whether to reset counters between tests.
    ///   - outputDirectory: Directory for coverage files.
    public static func coverage(
        isolatesTests: Bool = true,
        outputDirectory: String? = nil
    ) -> Self {
        Self(isolatesTests: isolatesTests, outputDirectory: outputDirectory)
    }
}

// MARK: - Coverage Utilities

@_spi(Experimental)
extension CoverageTrait {
    /// Whether coverage instrumentation is available for this test run.
    ///
    /// Returns `true` if the test binary was compiled with coverage
    /// instrumentation (`--enable-code-coverage`).
    public static var isAvailable: Bool {
        _coverageEnabled
    }
}
