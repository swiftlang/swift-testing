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

extension Test: TestContent {
  static var testContentKind: Int32 {
    100
  }

  typealias TestContentAccessorResult = @Sendable () async -> Self

  /// All available ``Test`` instances in the process, according to the runtime.
  ///
  /// The order of values in this sequence is unspecified.
  static var all: some Sequence<Self> {
    get async {
      var generators = [@Sendable () async -> [Self]]()

      // Figure out which discovery mechanism to use. By default, we'll use both
      // the legacy and new mechanisms, but we can set an environment variable
      // to explicitly select one or the other. When we remove legacy support,
      // we can also remove this enumeration and environment variable check.
      enum DiscoveryMode {
        case tryBoth
        case newOnly
        case legacyOnly
      }
      let discoveryMode: DiscoveryMode = switch Environment.flag(named: "SWT_USE_LEGACY_TEST_DISCOVERY") {
      case .none:
        .tryBoth
      case .some(true):
        .legacyOnly
      case .some(false):
        .newOnly
      }

      // Walk all test content and gather generator functions. Note we don't
      // actually call the generators yet because enumerating test content may
      // involve holding some internal lock such as the ones in libobjc or
      // dl_iterate_phdr(), and we don't want to accidentally deadlock if the
      // user code we call ends up loading another image.
      if discoveryMode != .legacyOnly {
        enumerateTestContent { imageAddress, generator, _, _ in
          nonisolated(unsafe) let imageAddress = imageAddress
          generators.append { @Sendable in
            var result = await generator()
#if !SWT_NO_DYNAMIC_LINKING
            result.imageAddress = imageAddress
#endif
            return [result]
          }
        }
      }

#if !SWT_NO_LEGACY_TEST_DISCOVERY
      if discoveryMode != .newOnly && generators.isEmpty {
        enumerateTypes(withNamesContaining: testContainerTypeNameMagic) { imageAddress, type, _ in
          guard let type = type as? any __TestContainer.Type else {
            return
          }
          nonisolated(unsafe) let imageAddress = imageAddress
          generators.append { @Sendable in
            var result = await type.__tests
#if !SWT_NO_DYNAMIC_LINKING
            for i in 0 ..< result.count {
              result[i].imageAddress = imageAddress
            }
#endif
            return result
          }
        }
      }
#endif

      // *Now* we call all the generators and return their results.
      // Reduce into a set rather than an array to deduplicate tests that were
      // generated multiple times (e.g. from multiple discovery modes or from
      // defective test records.)
      return await withTaskGroup(of: [Self].self) { taskGroup in
        for generator in generators {
          taskGroup.addTask {
            await generator()
          }
        }
        return await taskGroup.reduce(into: Set()) { $0.formUnion($1) }
      }
    }
  }
}
