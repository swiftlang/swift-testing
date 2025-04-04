//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// A protocol describing a type that can be represented by a test content
/// record, stored in the test content section of a Swift binary at compile
/// time, and dynamically discovered at runtime.
///
/// Types conforming to this protocol must also conform to [`Sendable`](https://developer.apple.com/documentation/swift/sendable)
/// because they may be discovered within any isolation context or within
/// multiple isolation contexts running concurrently.
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public protocol DiscoverableAsTestContent: Sendable, ~Copyable {
  /// The value of the `kind` field in test content records associated with this
  /// type.
  ///
  /// The value of this property is reserved for each test content type. See
  /// `ABI/TestContent.md` for a list of values and corresponding types.
  static var testContentKind: TestContentKind { get }

  /// The type of the `context` field in test content records associated with
  /// this type.
  ///
  /// By default, this type equals `UInt`. This type can be set to some other
  /// type with the same stride and alignment as `UInt`. Using a type with
  /// different stride or alignment will result in a failure when trying to
  /// discover test content records associated with this type.
  associatedtype TestContentContext: BitwiseCopyable = UInt

  /// A type of "hint" passed to ``allTestContentRecords()`` to help the testing
  /// library find the correct result.
  ///
  /// By default, this type equals `Never`, indicating that this type of test
  /// content does not support hinting during discovery.
  associatedtype TestContentAccessorHint = Never

#if !SWT_NO_LEGACY_TEST_DISCOVERY
  /// A string present in the names of types containing test content records
  /// associated with this type.
  @available(swift, deprecated: 100000.0, message: "Do not adopt this functionality in new code. It will be removed in a future release.")
  static var _testContentTypeNameHint: String { get }
#endif
}

#if !SWT_NO_LEGACY_TEST_DISCOVERY
extension DiscoverableAsTestContent where Self: ~Copyable {
  public static var _testContentTypeNameHint: String {
    "__🟡$"
  }
}
#endif
