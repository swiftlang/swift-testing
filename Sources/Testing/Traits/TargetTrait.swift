//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) import _TestDiscovery

/// A protocol describing a trait that you can add to a test target.
///
/// A target trait can be applied to all tests in a given target. Target traits
/// always conform to ``SuiteTrait`` because a test target is, effectively, a
/// top-level suite.
///
/// The testing library defines a number of traits that you can add to test
/// targets. You can also define your own traits by creating types that
/// conform to this protocol, the ``TestTrait`` protocol, or the ``SuiteTrait``
/// protocol.
@_spi(Experimental)
public protocol TargetTrait: SuiteTrait {}

/// Apply traits to the current test target.
///
/// - Parameters:
///   - traits: One or more traits to apply to the current test target.
///
/// Each trait in `traits` is applied to the entire test target and, for those
/// traits whose `isRecursive` property is `true`, suites and tests contained
/// within that target.
@_spi(Experimental)
@freestanding(declaration)
public macro targetTraits(
  _ traits: any TargetTrait...
) = #externalMacro(module: "TestingMacros", type: "TargetTraitsMacro")

/// A type representing zero or more target traits (traits conforming to
/// ``TargetTrait``) that have been discovered at runtime.
///
/// This type is not part of the public interface of the testing library.
struct TargetTraitsList: DiscoverableAsTestContent, Sendable {
  static var testContentKind: TestContentKind {
    "tgtr"
  }

  var generator: @Sendable () async -> [any TargetTrait]

  var moduleName: String

  static var all: some Sequence<Self> {
    let result = Self.allTestContentRecords().compactMap { $0.load() }
    if !result.isEmpty {
      return result
    }

#if !SWT_NO_LEGACY_TEST_DISCOVERY
    return Self.allTypeMetadataBasedTestContentRecords().compactMap { $0.load() }
#endif
  }
}

/// Store the target traits list into the given memory.
///
/// - Parameters:
///   - generator: A function that, when called, returns zero or more test
///   	target traits to apply to the target identified by `sourceLocation`.
///   - outValue: The uninitialized memory to store the exit test into.
///   - typeAddress: A pointer to the expected type of the exit test as passed
///     to the test content record calling this function.
///   - sourceLocation: The source location of the call to the macro.
///
/// - Returns: Whether or not a target traits list was stored into `outValue`.
///
/// - Warning: This function is used to implement the `#targetTraits()`
///   macro. Do not use it directly.
@_spi(Experimental)
public func __store(
  _ generator: @escaping @Sendable () async -> [any TargetTrait],
  into outValue: UnsafeMutableRawPointer,
  asTypeAt typeAddress: UnsafeRawPointer,
  sourceLocation: SourceLocation = #_sourceLocation
) -> CBool {
#if !hasFeature(Embedded)
  guard typeAddress.load(as: Any.Type.self) == TargetTraitsList.self else {
    return false
  }
#endif

  let moduleName = rawIdentifierAwareSplit(sourceLocation.moduleName, separator: "/", maxSplits: 1)[0]
  outValue.initializeMemory(
    as: TargetTraitsList.self,
    to: .init(generator: generator, moduleName: String(moduleName))
  )

  return true
}
