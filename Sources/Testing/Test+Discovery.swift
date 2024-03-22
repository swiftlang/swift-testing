//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import TestingInternals

/// A protocol describing a type that contains tests.
///
/// - Warning: This protocol is used to implement the `@Test` macro. Do not use
///   it directly.
@_alwaysEmitConformanceMetadata
public protocol __TestContainer {
  /// The set of tests contained by this type.
  static var __tests: [Test] { get async }
}

extension Test {
  /// A string that appears within all auto-generated types conforming to the
  /// `__TestContainer` protocol.
  private static let _testContainerTypeNameMagic = "__🟠$test_container__"

  /// All available ``Test`` instances in the process, according to the runtime.
  ///
  /// The order of values in this sequence is unspecified.
  static var all: some Collection<Test> {
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
  private static var _all: some Collection<Self> {
    get async {
      await withTaskGroup(of: [Self].self) { taskGroup in
        swt_enumerateTypes(&taskGroup) { type, context in
          if let type = unsafeBitCast(type, to: Any.Type.self) as? any __TestContainer.Type {
            let taskGroup = context!.assumingMemoryBound(to: TaskGroup<[Self]>.self)
            taskGroup.pointee.addTask {
              await type.__tests
            }
          }
        } withNamesMatching: { typeName, _ in
          // strstr() lets us avoid copying either string before comparing.
          Self._testContainerTypeNameMagic.withCString { testContainerTypeNameMagic in
            nil != strstr(typeName, testContainerTypeNameMagic)
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
  ///
  /// - Bug: This function is necessary because containing type information is
  ///   not available during expansion of the `@Test` macro.
  ///   ([105470382](rdar://105470382))
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
        // If the real test is hidden, so shall the synthesized test be hidden.
        // Copy the exact traits from the real test in case they someday carry
        // any interesting metadata.
        let traits = test.traits.compactMap { $0 as? HiddenTrait }
        tests[suiteID] = Test(traits: traits, sourceLocation: test.sourceLocation, containingTypeInfo: suiteTypeInfo)
      }
    }

    return tests.count - originalCount
  }
}
