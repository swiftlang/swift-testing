//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A type that indicates that a test should be hidden from automatic discovery
/// and only run if explicitly requested.
///
/// This is different from disabled or skipped, and is primarily meant to be
/// used on tests defined in this project's own test suite, so that example
/// tests can be defined using the `@Test` attribute but not run by default
/// except by the specific unit test(s) which have requested to run them.
///
/// This type is not part of the public interface of the testing library.
struct HiddenTrait: TestTrait, SuiteTrait {
  var isRecursive: Bool {
    true
  }
}

extension Trait where Self == HiddenTrait {
  static var hidden: Self {
    HiddenTrait()
  }
}

extension Test {
  /// Whether this test is hidden, whether directly or via a trait inherited
  /// from a parent test.
  var isHidden: Bool {
    traits.contains { $0 is HiddenTrait }
  }
}
