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
protocol TestContent: ~Copyable {
  /// The unique "kind" value associated with this type.
  ///
  /// The value of this property is reserved for each test content type. See
  /// `ABI/TestContent.md` for a list of values and corresponding types.
  static var testContentKind: UInt32 { get }

  /// The type of value returned by the test content accessor for this type.
  ///
  /// This type may or may not equal `Self` depending on the type's compile-time
  /// and runtime requirements. If it does not equal `Self`, it should equal a
  /// type whose instances can be converted to instances of `Self` (e.g. by
  /// calling them if they are functions.)
  associatedtype TestContentAccessorResult: ~Copyable

  /// A type of "hint" passed to ``discover(withHint:)`` to help the testing
  /// library find the correct result.
  ///
  /// By default, this type equals `Never`, indicating that this type of test
  /// content does not support hinting during discovery.
  associatedtype TestContentAccessorHint: Sendable = Never
}

// MARK: - Individual test content records

/// A type describing a test content record of a particular (known) type.
///
/// Instances of this type can be created by calling
/// ``TestContent/allTestContentRecords()`` on a type that conforms to
/// ``TestContent``.
///
/// This type is not part of the public interface of the testing library. In the
/// future, we could make it public if we want to support runtime discovery of
/// test content by second- or third-party code.
struct TestContentRecord<T>: Sendable where T: ~Copyable {
  /// The base address of the image containing this instance, if known.
  ///
  /// This property is not available on platforms such as WASI that statically
  /// link to the testing library.
  ///
  /// - Note: The value of this property is distinct from the pointer returned
  ///   by `dlopen()` (on platforms that have that function) and cannot be used
  ///   with interfaces such as `dlsym()` that expect such a pointer.
#if SWT_NO_DYNAMIC_LINKING
  @available(*, unavailable, message: "Image addresses are not available on this platform.")
  nonisolated(unsafe) var imageAddress: UnsafeRawPointer? {
    get { fatalError() }
    set { fatalError() }
  }
#else
  nonisolated(unsafe) var imageAddress: UnsafeRawPointer?
#endif

  /// The underlying test content record loaded from a metadata section.
  private var _record: __TestContentRecord

  fileprivate init(imageAddress: UnsafeRawPointer?, record: __TestContentRecord) {
#if !SWT_NO_DYNAMIC_LINKING
    self.imageAddress = imageAddress
#endif
    self._record = record
  }
}

// This `T: TestContent` constraint is in an extension in order to work around a
// compiler crash. SEE: rdar://143049814
extension TestContentRecord where T: TestContent & ~Copyable {
  /// The context value for this test content record.
  var context: UInt {
    _record.context
  }

  /// Load the value represented by this record.
  ///
  /// - Parameters:
  ///   - hint: An optional hint value. If not `nil`, this value is passed to
  ///     the accessor function of the underlying test content record.
  ///
  /// - Returns: An instance of the associated ``TestContentAccessorResult``
  ///   type, or `nil` if the underlying test content record did not match
  ///   `hint` or otherwise did not produce a value.
  ///
  /// If this function is called more than once on the same instance, a new
  /// value is created on each call.
  func load(withHint hint: T.TestContentAccessorHint? = nil) -> T.TestContentAccessorResult? {
    guard let accessor = _record.accessor.map(swt_resign) else {
      return nil
    }

    return withUnsafeTemporaryAllocation(of: T.TestContentAccessorResult.self, capacity: 1) { buffer in
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

// MARK: - Enumeration of test content records

extension TestContent where Self: ~Copyable {
  /// Get all test content of this type known to Swift and found in the current
  /// process.
  ///
  /// - Returns: A sequence of instances of ``TestContentRecord``. Only test
  ///   content records matching this ``TestContent`` type's requirements are
  ///   included in the sequence.
  ///
  /// - Bug: This function returns an instance of `AnySequence` instead of an
  ///   opaque type due to a compiler crash. ([143080508](rdar://143080508))
  static func allTestContentRecords() -> AnySequence<TestContentRecord<Self>> {
    let result = SectionBounds.all(.testContent).lazy.flatMap { sb in
      sb.buffer.withMemoryRebound(to: __TestContentRecord.self) { records in
        records.lazy
          .filter { $0.kind == testContentKind }
          .map { TestContentRecord<Self>(imageAddress: sb.imageAddress, record: $0) }
      }
    }
    return AnySequence(result)
  }
}
