//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// Declare a type as a benchmark host.
///
/// - Warning: Benchmark support is experimental. Its interface is subject to
///   change.
///
/// Apply this macro to a type to make it discoverable by the testing library as a
/// ``Benchmark/Host``. The macro adds the conformance, if the type does not already
/// state it, and emits the test content record that lets the testing library find
/// the type at runtime:
///
/// ```swift
/// @BenchmarkHost
/// struct MyHost {
///   var identifier: String { "com.example.my-host" }
///
///   func run(
///     _ body: Benchmark.Body,
///     configuration: Benchmark.Configuration
///   ) throws -> Benchmark.Results {
///     // ...
///   }
/// }
/// ```
///
/// The type this macro is applied to must be non-generic and must be
/// default-initializable, because the testing library instantiates it from a C
/// function pointer that takes no arguments.
@attached(extension, conformances: Benchmark.Host)
@attached(member, names: named(__benchmarkHostRecord))
public macro BenchmarkHost() = #externalMacro(module: "TestingMacros", type: "BenchmarkHostMacro")
