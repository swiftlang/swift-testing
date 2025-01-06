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

/// Resign any pointers in a test content record.
///
/// - Parameters:
///   - record: The test content record to resign.
///
/// - Returns: A copy of `record` with its pointers resigned.
///
/// On platforms/architectures without pointer authentication, this function has
/// no effect.
private func _resign(_ record: __TestContentRecord) -> __TestContentRecord {
  var record = record
  record.accessor = record.accessor.map(swt_resign)
  return record
}

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

extension TestContent where Self: ~Copyable {
  /// Enumerate all test content records found in the given test content section
  /// in the current process that match this ``TestContent`` type.
  ///
  /// - Parameters:
  ///   - sectionBounds: The bounds of the section to inspect.
  ///
  /// - Returns: A sequence of tuples. Each tuple contains an instance of
  ///   `__TestContentRecord` and the base address of the image containing that
  ///   test content record. Only test content records matching this
  ///   ``TestContent`` type's requirements are included in the sequence.
  private static func _testContentRecords(in sectionBounds: SectionBounds) -> some Sequence<(imageAddress: UnsafeRawPointer?, record: __TestContentRecord)> {
    sectionBounds.buffer.withMemoryRebound(to: __TestContentRecord.self) { records in
      records.lazy
        .filter { $0.kind == testContentKind }
        .map(_resign)
        .map { (sectionBounds.imageAddress, $0) }
    }
  }

  /// Call the given accessor function.
  ///
  /// - Parameters:
  ///   - accessor: The C accessor function of a test content record matching
  ///     this type.
  ///   - hint: A pointer to a kind-specific hint value. If not `nil`, this
  ///     value is passed to `accessor`, allowing that function to determine if
  ///     its record matches before initializing its out-result.
  ///
  /// - Returns: An instance of this type's accessor result or `nil` if an
  ///   instance could not be created (or if `hint` did not match.)
  ///
  /// The caller is responsible for ensuring that `accessor` corresponds to a
  /// test content record of this type.
  private static func _callAccessor(_ accessor: SWTTestContentAccessor, withHint hint: TestContentAccessorHint?) -> TestContentAccessorResult? {
    withUnsafeTemporaryAllocation(of: TestContentAccessorResult.self, capacity: 1) { buffer in
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

  /// The type of callback called by ``enumerateTestContent(withHint:_:)``.
  ///
  /// - Parameters:
  ///   - imageAddress: A pointer to the start of the image. This value is _not_
  ///     equal to the value returned from `dlopen()`. On platforms that do not
  ///     support dynamic loading (and so do not have loadable images), the
  ///     value of this argument is unspecified.
  ///   - content: The value produced by the test content record's accessor.
  ///   - context: Context associated with `content`. The value of this argument
  ///     is dependent on the type of test content being enumerated.
  ///   - stop: An `inout` boolean variable indicating whether test content
  ///     enumeration should stop after the function returns. Set `stop` to
  ///     `true` to stop test content enumeration.
  typealias TestContentEnumerator = (_ imageAddress: UnsafeRawPointer?, _ content: borrowing TestContentAccessorResult, _ context: UInt, _ stop: inout Bool) -> Void

  /// Enumerate all test content of this type known to Swift and found in the
  /// current process.
  ///
  /// - Parameters:
  ///   - kind: The kind of test content to look for.
  ///   - type: The Swift type of test content to look for.
  ///   - hint: A pointer to a kind-specific hint value. If not `nil`, this
  ///     value is passed to each test content record's accessor function,
  ///     allowing that function to determine if its record matches before
  ///     initializing its out-result.
  ///   - body: A function to invoke, once per matching test content record.
  ///
  /// This function uses a callback instead of producing a sequence because it
  /// is used with move-only types (specifically ``ExitTest``) and
  /// `Sequence.Element` must be copyable.
  static func enumerateTestContent(withHint hint: TestContentAccessorHint? = nil, _ body: TestContentEnumerator) {
    let testContentRecords = SectionBounds.allTestContent.lazy.flatMap(_testContentRecords(in:))

    var stop = false
    for (imageAddress, record) in testContentRecords {
      if let accessor = record.accessor, let result = _callAccessor(accessor, withHint: hint) {
        // Call the callback.
        body(imageAddress, result, record.context, &stop)
        if stop {
          break
        }
      }
    }
  }
}
