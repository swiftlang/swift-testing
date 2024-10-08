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
      await withTaskGroup(of: [Self].self) { taskGroup in
        enumerateTypes(withNamesContaining: testContainerTypeNameMagic) { _, type, _ in
          if let type = type as? any __TestContainer.Type {
            taskGroup.addTask {
              await type.__tests
            }
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
