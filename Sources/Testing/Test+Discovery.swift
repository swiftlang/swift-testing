//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

extension Test {
  /// A type that encapsulates test content records that produce instances of
  /// ``Test``.
  ///
  /// This type is necessary because such test content records produce an
  /// indirect `async` accessor function rather than directly producing
  /// instances of ``Test``, but functions are non-nominal types and cannot
  /// directly conform to protocols.
  ///
  /// - Note: This helper type must have the exact in-memory layout of the
  ///   `async` accessor function. Do not add any additional cases or associated
  ///   values. The layout of this type is [guaranteed](https://github.com/swiftlang/swift/blob/main/docs/ABI/TypeLayout.rst#fragile-enum-layout)
  ///   by the Swift ABI.
  /* @frozen */ private enum _Record: TestContent {
    static var testContentKind: UInt32 {
      0x74657374
    }

    /// The actual (asynchronous) accessor function.
    case generator(@Sendable () async -> Test)
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

      // Figure out which discovery mechanism to use. By default, we'll use both
      // the legacy and new mechanisms, but we can set an environment variable
      // to explicitly select one or the other. When we remove legacy support,
      // we can also remove this enumeration and environment variable check.
      let (useNewMode, useLegacyMode) = switch Environment.flag(named: "SWT_USE_LEGACY_TEST_DISCOVERY") {
      case .none:
        (true, true)
      case .some(true):
        (false, true)
      case .some(false):
        (true, false)
      }

      // Walk all test content and gather generator functions, then call them in
      // a task group and collate their results.
      if useNewMode {
        let generators = _Record.allTestContentRecords().lazy.compactMap { record in
          if case let .generator(generator) = record.load() {
            return generator
          }
          return nil // currently unreachable, but not provably so
        }
        await withTaskGroup(of: Self.self) { taskGroup in
          for generator in generators {
            taskGroup.addTask(operation: generator)
          }
          result = await taskGroup.reduce(into: result) { $0.insert($1) }
        }
      }

      // Perform legacy test discovery if needed.
      if useLegacyMode && result.isEmpty {
        let types = types(withNamesContaining: testContainerTypeNameMagic).lazy
          .compactMap { $0 as? any __TestContainer.Type }
        await withTaskGroup(of: [Self].self) { taskGroup in
          for type in types {
            taskGroup.addTask {
              await type.__tests
            }
          }
          result = await taskGroup.reduce(into: result) { $0.formUnion($1) }
        }
      }

      return result
    }
  }
}
