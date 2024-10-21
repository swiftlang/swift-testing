//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

extension Test {
  /// All available ``Test`` instances in the process, according to the runtime.
  ///
  /// The order of values in this sequence is unspecified.
  static var all: some Sequence<Test> {
    get async {
      // Convert the raw sequence of tests to a dictionary keyed by ID.
      var result = await testsByID(_all)

      // Ensure test suite types that don't have the @Suite attribute are still
      // represented in the result.
      _synthesizeSuiteTypes(into: &result)

      return result.values
    }
  }

  /// All available ``Test`` instances in the process, according to the runtime.
  ///
  /// The order of values in this sequence is unspecified. This sequence may
  /// contain duplicates; callers should use ``all`` instead.
  private static var _all: some Sequence<Self> {
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
        enumerateTestContent(ofKind: .testDeclaration, as: (@Sendable () async -> Test).self) { imageAddress, generator, _, _ in
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
      if discoveryMode != .newOnly || generators.isEmpty {
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
      return await withTaskGroup(of: [Self].self) { taskGroup in
        for generator in generators {
          taskGroup.addTask {
            await generator()
          }
        }
        return await taskGroup.reduce(into: [], +=)
      }
    }
  }

  /// Create a dictionary mapping the IDs of a sequence of tests to those tests.
  ///
  /// - Parameters:
  ///   - tests: The sequence to convert to a dictionary.
  ///
  /// - Returns: A dictionary containing `tests` keyed by those tests' IDs.
  static func testsByID(_ tests: some Sequence<Self>) -> [ID: Self] {
    [ID: Self](
      tests.lazy.map { ($0.id, $0) },
      uniquingKeysWith: { existing, _ in existing }
    )
  }

  /// Synthesize any missing test suite types (that is, types containing test
  /// content that do not have the `@Suite` attribute) and add them to a
  /// dictionary of tests.
  ///
  /// - Parameters:
  ///   - tests: A dictionary of tests to amend.
  ///
  /// - Returns: The number of key-value pairs added to `tests`.
  @discardableResult private static func _synthesizeSuiteTypes(into tests: inout [ID: Self]) -> Int {
    let originalCount = tests.count

    // Find any instances of Test in the input that are *not* suites. We'll be
    // checking the containing types of each one.
    for test in tests.values where !test.isSuite {
      guard let suiteTypeInfo = test.containingTypeInfo else {
        continue
      }
      let suiteID = ID(typeInfo: suiteTypeInfo)
      if tests[suiteID] == nil {
        tests[suiteID] = Test(traits: [], sourceLocation: test.sourceLocation, containingTypeInfo: suiteTypeInfo, isSynthesized: true)

        // Also synthesize any ancestral suites that don't have tests.
        for ancestralSuiteTypeInfo in suiteTypeInfo.allContainingTypeInfo {
          let ancestralSuiteID = ID(typeInfo: ancestralSuiteTypeInfo)
          if tests[ancestralSuiteID] == nil {
            tests[ancestralSuiteID] = Test(traits: [], sourceLocation: test.sourceLocation, containingTypeInfo: ancestralSuiteTypeInfo, isSynthesized: true)
          }
        }
      }
    }

    return tests.count - originalCount
  }
}

// MARK: - Test content enumeration

extension UnsafePointer<SWTTestContentHeader> {
  /// Get the implied `n_name` field.
  ///
  /// If this test content header has no name, or if the name is not
  /// null-terminated, the value of this property is `nil`.
  fileprivate var n_name: UnsafePointer<CChar>? {
    let n_namesz = Int(pointee.n_namesz)
    return (self + 1).withMemoryRebound(to: CChar.self, capacity: n_namesz) { name in
      if strnlen(name, n_namesz) >= n_namesz {
        // There is no trailing null byte within the provided length.
        return nil
      }
      return name
    }
  }

  /// The implied `n_desc` field.
  ///
  /// If this test content header has no description (payload), the value of
  /// this property is `nil`.
  fileprivate var n_desc: UnsafeRawPointer? {
    let n_descsz = Int(pointee.n_descsz)
    if n_descsz <= 0 {
      return nil
    }
    let n_namesz = Int(pointee.n_namesz)
    return UnsafeRawPointer(self + 1) + swt_alignup(n_namesz, MemoryLayout<UInt32>.alignment)
  }
}

/// The content of a test content record.
///
/// - Parameters:
///   - accessor: A function which, when called, produces the test content as a
///     retained Swift object. If this function returns `true`, the caller is
///     responsible for deinitializing the memory at `outValue` when done.
///   - flags: Flags for this record. The meaning of this value is dependent on
///     the kind of test content this instance represents.
private typealias _TestContent = (
  accessor: (@convention(c) (_ outValue: UnsafeMutableRawPointer) -> Bool)?,
  flags: UInt32
)

/// An enumeration representing the different kinds of test content known to the
/// testing library.
///
/// When adding cases to this enumeration, be sure to also update the
/// corresponding enumeration in TestContentGeneration.swift and TestContent.md.
enum TestContentKind: Int32 {
  /// A test or suite declaration.
  case testDeclaration = 100

  /// An exit test.
  case exitTest = 101
}

/// The type of callback called by ``enumerateTestContent(ofKind:as:_:)``.
///
/// - Parameters:
///   - imageAddress: A pointer to the start of the image. This value is _not_
///     equal to the value returned from `dlopen()`. On platforms that do not
///     support dynamic loading (and so do not have loadable images), the value
///     of this argument is unspecified.
///   - content: The enumerated test content.
///   - flags: Flags associated with `content`. The value of this argument is
///     dependent on the type of test content being enumerated.
///   - stop: An `inout` boolean variable indicating whether test content
///     enumeration should stop after the function returns. Set `stop` to `true`
///     to stop test content enumeration.
typealias TestContentEnumerator<T> = (_ imageAddress: UnsafeRawPointer?, _ content: borrowing T, _ flags: UInt32, _ stop: inout Bool) -> Void where T: ~Copyable

/// Enumerate all test content known to Swift and found in the current process.
///
/// - Parameters:
///   - kind: The kind of test content to look for.
///   - type: The Swift type of test content to look for.
///   - body: A function to invoke, once per matching test content record.
func enumerateTestContent<T>(ofKind kind: TestContentKind, as type: T.Type, _ body: TestContentEnumerator<T>) where T: ~Copyable {
  // Wrap the `body` closure in a non-generic closure that we can load from
  // within the C callback below.
  typealias RawTestContentEnumerator = (_ imageAddress: UnsafeRawPointer?, _ header: UnsafePointer<SWTTestContentHeader>, _ stop: UnsafeMutablePointer<Bool>) -> Void
  let body: RawTestContentEnumerator = { imageAddress, header, stop in
    // We only care about test content records with the specified kind and the
    // "Swift Testing" name.
    guard header.pointee.n_type == kind.rawValue,
          let n_name = header.n_name, 0 == strcmp(n_name, "Swift Testing") else {
      return
    }
    withUnsafeTemporaryAllocation(of: type, capacity: 1) { buffer in
      // Load the content from the record via its accessor function. Unaligned
      // because the underlying C structure only guarantees 4-byte alignment
      // even on 64-bit systems.
      guard let content = header.n_desc?.loadUnaligned(as: _TestContent.self),
            content.accessor?(buffer.baseAddress!) == true else {
        return
      }
      defer {
        buffer.deinitialize()
      }

      // Call the callback.
      body(imageAddress, buffer.baseAddress!.pointee, content.flags, &stop.pointee)
    }
  }

  withoutActuallyEscaping(body) { body in
    withUnsafePointer(to: body) { context in
      swt_enumerateTestContent(.init(mutating: context)) { imageAddress, header, stop, context in
        let body = context!.load(as: RawTestContentEnumerator.self)
        body(imageAddress, header, stop)
      }
    }
  }
}
