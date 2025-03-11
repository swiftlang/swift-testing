//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) private import _TestDiscovery
private import _TestingInternals

extension Test {
  /// A type that encapsulates test content records that produce instances of
  /// ``Test``.
  ///
  /// This type is necessary because such test content records produce an
  /// indirect `async` accessor function rather than directly producing
  /// instances of ``Test``, but functions are non-nominal types and cannot
  /// directly conform to protocols.
  fileprivate struct Generator: DiscoverableAsTestContent, RawRepresentable {
    static var testContentKind: TestContentKind {
      "test"
    }

    var rawValue: @Sendable () async -> Test
  }

  /// Store the test generator function into the given memory.
  ///
  /// - Parameters:
  ///   - generator: The generator function to store.
  ///   - outValue: The uninitialized memory to store `generator` into.
  ///   - typeAddress: A pointer to the expected type of `generator` as passed
  ///     to the test content record calling this function.
  ///
  /// - Returns: Whether or not `generator` was stored into `outValue`.
  ///
  /// - Warning: This function is used to implement the `@Test` macro. Do not
  ///   use it directly.
  public static func __store(
    _ generator: @escaping @Sendable () async -> Test,
    into outValue: UnsafeMutableRawPointer,
    asTypeAt typeAddress: UnsafeRawPointer
  ) -> CBool {
    guard typeAddress.load(as: Any.Type.self) == Generator.self else {
      return false
    }
    outValue.initializeMemory(as: Generator.self, to: .init(rawValue: generator))
    return true
  }

  /// All available ``Test`` instances in the process, according to the runtime.
  ///
  /// The order of values in this sequence is unspecified.
  static var all: some Sequence<Self> {
    get async {
      // The result is a set rather than an array to deduplicate tests that were
      // generated multiple times (e.g. from multiple discovery modes or from
      // defective test records.)
      var result = Set<Self>()

      // Walk all test content and gather generator functions, then call them in
      // a task group and collate their results.
      let generators = Generator.allTestContentRecords().lazy.compactMap { $0.load() }
      await withTaskGroup(of: Self.self) { taskGroup in
        for generator in generators {
          taskGroup.addTask { await generator.rawValue() }
        }
        result = await taskGroup.reduce(into: result) { $0.insert($1) }
      }

      return result
    }
  }
}
