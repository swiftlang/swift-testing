//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// This file provides support for the `@Benchmark` macro. Other than the macro
/// itself, the symbols in this file should not be used directly and are subject
/// to change as the testing library evolves.

// MARK: - @Test

/// This macro declaration is necessary to help the compiler disambiguate
/// display names from traits, but it does not need to be documented separately.
///
/// ## See Also
///
/// - ``Benchmark(_:_:)``
@attached(peer)
@_documentation(visibility: private)
public macro Benchmark(
  _ traits: any TestTrait...
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro")

/// Declare a benchmark.
///
/// - Parameters:
///   - displayName: The customized display name of this test. If the value of
///     this argument is `nil`, the display name of the test is derived from the
///     associated function's name.
///   - traits: Zero or more traits to apply to this test.
///
/// ## See Also
///
/// - <doc:DefiningBenchmarks>
@attached(peer) public macro Benchmark(
  _ displayName: _const String? = nil,
  _ traits: any TestTrait...
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro")

// MARK: - @Benchmark(arguments:)

/// This macro declaration is necessary to help the compiler disambiguate
/// display names from traits, but it does not need to be documented separately.
///
/// ## See Also
///
/// - ``Benchmark(_:arguments:)-35dat``
@attached(peer)
@_documentation(visibility: private)
public macro Benchmark<C>(
  _ traits: any TestTrait...,
  arguments collection: C
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro") where C: Collection & Sendable, C.Element: Sendable

/// Declare a test parameterized over a collection of values.
///
/// - Parameters:
///   - displayName: The customized display name of this test. If the value of
///     this argument is `nil`, the display name of the test is derived from the
///     associated function's name.
///   - traits: Zero or more traits to apply to this test.
///   - collection: A collection of values to pass to the associated test
///     function.
///
/// You can prefix the expression you pass to `collection` with `try` or `await`.
/// The testing library evaluates the expression lazily only if it determines
/// that the associated test will run. During testing, the testing library calls
/// the associated test function once for each element in `collection`.
///
/// @Comment {
///   - Bug: The testing library should support variadic generics.
///     ([103416861](rdar://103416861))
/// }
///
/// ## See Also
///
/// - <doc:DefiningTests>
@attached(peer) public macro Benchmark<C>(
  _ displayName: _const String? = nil,
  _ traits: any TestTrait...,
  arguments collection: C
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro") where C: Collection & Sendable, C.Element: Sendable

// MARK: - @Test(arguments:_:)

/// Declare a test parameterized over two collections of values.
///
/// - Parameters:
///   - traits: Zero or more traits to apply to this test.
///   - collection1: A collection of values to pass to `testFunction`.
///   - collection2: A second collection of values to pass to `testFunction`.
///
/// You can prefix the expressions you pass to `collection1` or `collection2`
/// with `try` or `await`. The testing library evaluates the expressions lazily
/// only if it determines that the associated test will run. During testing, the
/// testing library calls the associated test function once for each pair of
/// elements in `collection1` and `collection2`.
///
/// @Comment {
///   - Bug: The testing library should support variadic generics.
///     ([103416861](rdar://103416861))
/// }
///
/// ## See Also
///
/// - <doc:DefiningTests>
@attached(peer)
@_documentation(visibility: private)
public macro Benchmark<C1, C2>(
  _ traits: any TestTrait...,
  arguments collection1: C1, _ collection2: C2
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro") where C1: Collection & Sendable, C1.Element: Sendable, C2: Collection & Sendable, C2.Element: Sendable

/// Declare a test parameterized over two collections of values.
///
/// - Parameters:
///   - displayName: The customized display name of this test. If the value of
///     this argument is `nil`, the display name of the test is derived from the
///     associated function's name.
///   - traits: Zero or more traits to apply to this test.
///   - collection1: A collection of values to pass to `testFunction`.
///   - collection2: A second collection of values to pass to `testFunction`.
///
/// You can prefix the expressions you pass to `collection1` or `collection2`
/// with `try` or `await`. The testing library evaluates the expressions lazily
/// only if it determines that the associated test will run. During testing, the
/// testing library calls the associated test function once for each pair of
/// elements in `collection1` and `collection2`.
///
/// @Comment {
///   - Bug: The testing library should support variadic generics.
///     ([103416861](rdar://103416861))
/// }
///
/// ## See Also
///
/// - <doc:DefiningTests>
@attached(peer) public macro Benchmark<C1, C2>(
  _ displayName: _const String? = nil,
  _ traits: any TestTrait...,
  arguments collection1: C1, _ collection2: C2
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro") where C1: Collection & Sendable, C1.Element: Sendable, C2: Collection & Sendable, C2.Element: Sendable

// MARK: - @Test(arguments: zip(...))

/// Declare a test parameterized over two zipped collections of values.
///
/// - Parameters:
///   - traits: Zero or more traits to apply to this test.
///   - zippedCollections: Two zipped collections of values to pass to
///     `testFunction`.
///
/// You can prefix the expression you pass to `zippedCollections` with `try` or
/// `await`. The testing library evaluates the expression lazily only if it
/// determines that the associated test will run. During testing, the testing
/// library calls the associated test function once for each element in
/// `zippedCollections`.
///
/// @Comment {
///   - Bug: The testing library should support variadic generics.
///     ([103416861](rdar://103416861))
/// }
///
/// ## See Also
///
/// - <doc:DefiningTests>
@attached(peer)
@_documentation(visibility: private)
public macro Benchmark<C1, C2>(
  _ traits: any TestTrait...,
  arguments zippedCollections: Zip2Sequence<C1, C2>
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro") where C1: Collection & Sendable, C1.Element: Sendable, C2: Collection & Sendable, C2.Element: Sendable

/// Declare a test parameterized over two zipped collections of values.
///
/// - Parameters:
///   - displayName: The customized display name of this test. If the value of
///     this argument is `nil`, the display name of the test is derived from the
///     associated function's name.
///   - traits: Zero or more traits to apply to this test.
///   - zippedCollections: Two zipped collections of values to pass to
///     `testFunction`.
///
/// You can prefix the expression you pass to `zippedCollections` with `try` or
/// `await`. The testing library evaluates the expression lazily only if it
/// determines that the associated test will run. During testing, the testing
/// library calls the associated test function once for each element in
/// `zippedCollections`.
///
/// @Comment {
///   - Bug: The testing library should support variadic generics.
///     ([103416861](rdar://103416861))
/// }
///
/// ## See Also
///
/// - <doc:DefiningTests>
@attached(peer) public macro Benchmark<C1, C2>(
  _ displayName: _const String? = nil,
  _ traits: any TestTrait...,
  arguments zippedCollections: Zip2Sequence<C1, C2>
) = #externalMacro(module: "TestingMacros", type: "TestDeclarationMacro") where C1: Collection & Sendable, C1.Element: Sendable, C2: Collection & Sendable, C2.Element: Sendable
