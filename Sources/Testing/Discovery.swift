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

/// The content of a test content record.
///
/// - Parameters:
///   - kind: The kind of this record.
///   - reserved1: Reserved for future use.
///   - accessor: A function which, when called, produces the test content.
///   - context: Kind-specific context for this record.
///   - reserved2: Reserved for future use.
///
/// - Warning: This type is used to implement the `@Test` macro. Do not use it
///   directly.
public typealias __TestContentRecord = (
  kind: UInt32,
  reserved1: UInt32,
  accessor: (@convention(c) (_ outValue: UnsafeMutableRawPointer, _ hint: UnsafeRawPointer?) -> CBool)?,
  context: UInt,
  reserved2: UInt
)

// MARK: -

/// A protocol describing a type that can be stored as test content at compile
/// time and later discovered at runtime.
///
/// This protocol is used to bring some Swift type safety to the ABI described
/// in `ABI/TestContent.md`. Refer to that document for more information about
/// this protocol's requirements.
///
/// This protocol is not part of the public interface of the testing library. In
/// the future, we could make it public if we want to support runtime discovery
/// of test content by second- or third-party code.
@_spi(Experimental)
public protocol UnsafeDiscoverable: Sendable, ~Copyable {
  /// The unique "kind" value associated with this type.
  ///
  /// The value of this property is globally reserved by each discoverable type.
  /// To reserve a "kind" value, open a [new GitHub issue](...) against the testing library.
  static var discoverableKind: UInt32 { get }

  /// The type of context associated with a test content record of this type.
  ///
  /// Test content records include a field with the same alignment, size, and
  /// stride as `UInt`, of this type. By default, the testing library assumes
  /// that type type of this field is `UInt` and is otherwise unspecialized, but
  /// discoverable types may specify another type such as `Int`  or a pointer
  /// type.
  associatedtype DiscoverableContext = UInt

  /// A type of "hint" passed to ``load(withHint:)`` to help the testing library
  /// find the correct result.
  ///
  /// By default, this type equals `Never`, indicating that this type of test
  /// content does not support hinting during discovery.
  associatedtype DiscoverableHint: Sendable = Never
}

/// A type representing test content records of a given type that have been
/// discovered at runtime.
///
/// To get an instance of the discoverable type `D`, call this type's
/// ``load(withHint:)`` function.
@_spi(Experimental)
public struct DiscoverableRecord<D>: Sendable where D: UnsafeDiscoverable & ~Copyable {
  /// The base address of the image containing this instance, if known.
  ///
  /// On platforms such as WASI that statically link to the testing library, the
  /// value of this property is always `nil`.
  ///
  /// - Note: The value of this property is distinct from the pointer returned
  ///   by `dlopen()` (on platforms that have that function) and cannot be used
  ///   with interfaces such as `dlsym()` that expect such a pointer.
  private nonisolated(unsafe) var _imageAddress: UnsafeRawPointer?

  /// The underlying test content record loaded from a metadata section.
  private var _record: __TestContentRecord

  fileprivate init(imageAddress: UnsafeRawPointer?, record: __TestContentRecord) {
    _imageAddress = imageAddress
    _record = record
  }

  /// The unique "kind" value associated with the discoverable type `D`.
  ///
  /// The value of this property is globally reserved by each discoverable type.
  /// To reserve a "kind" value, open a [new GitHub issue](...) against the testing library.
  public var kind: UInt32 {
    _record.kind
  }

  /// Load the value represented by this record.
  ///
  /// - Parameters:
  ///   - hint: An optional hint value. If not `nil`, this value is passed to
  ///     the accessor function of the underlying test content record.
  ///
  /// - Returns: An instance of the test content type `T`, or `nil` if the
  ///   underlying test content record did not match `hint` or otherwise did not
  ///   produce a value.
  ///
  /// If this function is called more than once on the same instance, a new
  /// value is created on each call.
  public func load(withHint hint: D.DiscoverableHint? = nil) -> D? {
    guard let accessor = _record.accessor else {
      return nil
    }

    return withUnsafeTemporaryAllocation(of: D.self, capacity: 1) { buffer in
      let initialized = if let hint {
        withUnsafePointer(to: hint) { hint in
          accessor(buffer.baseAddress!, hint)
        }
      } else {
        accessor(buffer.baseAddress!, nil)
      }
      guard initialized else {
        return nil
      }
      return buffer.baseAddress!.move()
    }
  }
}

extension DiscoverableRecord where D.DiscoverableContext: BinaryInteger, D.DiscoverableContext.Magnitude == UInt {
  /// The context value for this test content record.
  public var context: D.DiscoverableContext {
    D.DiscoverableContext(truncatingIfNeeded: _record.context)
  }
}

extension DiscoverableRecord where D.DiscoverableContext: RawRepresentable, D.DiscoverableContext.RawValue: BinaryInteger, D.DiscoverableContext.RawValue.Magnitude == UInt {
  /// The context value for this test content record.
  public var context: D.DiscoverableContext? {
    D.DiscoverableContext(rawValue: .init(truncatingIfNeeded: _record.context))
  }
}

extension DiscoverableRecord where D.DiscoverableContext: _Pointer {
  /// The context value for this test content record.
  public var context: D.DiscoverableContext? {
    D.DiscoverableContext(bitPattern: _record.context)
  }
}

// MARK: - Enumeration of test content records

extension UnsafeDiscoverable where Self: ~Copyable {
  /// Get all test content of this type known to Swift and found in the current
  /// process.
  ///
  /// - Returns: A sequence of instances of ``DiscoverableRecord``. Only records
  ///   matching this ``UnsafeDiscoverable`` type's requirements are included in
  ///   the sequence.
  ///
  // @Comment {
  //   - Bug: This function returns an instance of `AnySequence` instead of an
  //     opaque type due to a compiler crash. ([143080508](rdar://143080508))
  // }
  @_spi(Experimental)
  public static func discoverAllRecords() -> AnySequence<DiscoverableRecord<Self>> {
    let result = SectionBounds.all(.testContent).lazy.flatMap { sb in
      sb.buffer.withMemoryRebound(to: __TestContentRecord.self) { records in
        records.lazy
          .filter { $0.kind == discoverableKind }
          .map { DiscoverableRecord<Self>(imageAddress: sb.imageAddress, record: $0) }
      }
    }
    return AnySequence(result)
  }
}
