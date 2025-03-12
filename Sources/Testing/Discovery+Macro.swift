//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental) @_spi(ForToolsIntegrationOnly) internal import _TestDiscovery

/// A shadow declaration of `_TestDiscovery.DiscoverableAsTestContent` that
/// allows us to add public conformances to it without causing the
/// `_TestDiscovery` module to appear in `Testing.private.swiftinterface`.
///
/// This protocol is not part of the public interface of the testing library.
protocol DiscoverableAsTestContent: _TestDiscovery.DiscoverableAsTestContent, ~Copyable {}

/// The type of the accessor function used to access a test content record.
///
/// The signature of this function type must match that of the corresponding
/// type in the `_TestDiscovery` module. For more information, see
/// `ABI/TestContent.md`.
///
/// - Warning: This type is used to implement the `@Test` macro. Do not use it
///   directly.
public typealias __TestContentRecordAccessor = @convention(c) (
  _ outValue: UnsafeMutableRawPointer,
  _ type: UnsafeRawPointer,
  _ hint: UnsafeRawPointer?,
  _ reserved: UnsafeRawPointer?
) -> CBool

/// The content of a test content record.
///
/// The layout of this type must match that of the corresponding type
/// in the `_TestDiscovery` module. For more information, see
/// `ABI/TestContent.md`.
///
/// - Warning: This type is used to implement the `@Test` macro. Do not use it
///   directly.
public typealias __TestContentRecord = (
  kind: UInt32,
  reserved1: UInt32,
  accessor: __TestContentRecordAccessor?,
  context: UInt,
  reserved2: UInt
)
