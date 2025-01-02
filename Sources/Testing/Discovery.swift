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

/// The value of the implicit `n_name` field of ``SWTTestContentHeader`` for
/// all recognized test content records.
///
/// This value must match the value of `_testContentHeaderName` in
/// TestContentGeneration.swift.
private let _testContentHeaderName = Array("Swift Testing".utf8CString)

extension UnsafePointer<SWTTestContentHeader> {
  /// The size of the implied `n_name` field, in bytes.
  ///
  /// This value is rounded up to ensure 32-bit alignment of the fields in the
  /// test content header and record.
  fileprivate var n_namesz: Int {
    Int(max(0, pointee.n_namesz)).alignedUp(for: UInt32.self)
  }

  /// Get the implied `n_name` field.
  ///
  /// If this test content header has no name, or if the name is not
  /// null-terminated, the value of this property is `nil`.
  fileprivate var n_name: UnsafePointer<CChar>? {
    if n_namesz <= 0 {
      return nil
    }
    return (self + 1).withMemoryRebound(to: CChar.self, capacity: n_namesz) { name in
      if strnlen(name, n_namesz) >= n_namesz {
        // There is no trailing null byte within the provided length.
        return nil
      }
      return name
    }
  }

  /// The size of the implied `n_name` field, in bytes.
  ///
  /// This value is rounded up to ensure 32-bit alignment of the fields in the
  /// test content header and record.
  fileprivate var n_descsz: Int {
    Int(max(0, pointee.n_descsz)).alignedUp(for: UInt32.self)
  }

  /// The implied `n_desc` field.
  ///
  /// If this test content header has no description (payload), the value of
  /// this property is `nil`.
  fileprivate var n_desc: UnsafeRawPointer? {
    if n_descsz <= 0 {
      return nil
    }
    return UnsafeRawPointer(self + 1) + n_namesz
  }

  /// The number of bytes in this test content header, including all fields and
  /// padding.
  ///
  /// The address at `UnsafeRawPointer(self) + self.byteCount` is the start of
  /// the next test content header in the same section (if there is one.)
  fileprivate var byteCount: Int {
    MemoryLayout<Pointee>.stride + n_namesz + n_descsz
  }
}

// MARK: -

extension SectionBounds {
  /// All test content headers found in this test content section.
  fileprivate var testContentHeaders: some Sequence<UnsafePointer<SWTTestContentHeader>> {
    let firstHeader = start.assumingMemoryBound(to: SWTTestContentHeader.self)
    let end = start + size

    // Generate an infinite sequence of (possible) header addresses, then prefix
    // it to those that are actually contained within the section.
    return sequence(first: firstHeader) { header in
      (UnsafeRawPointer(header) + header.byteCount).assumingMemoryBound(to: SWTTestContentHeader.self)
    }.lazy.prefix { header in
      header >= start && header < end
        && (header + 1) <= end
        && UnsafeRawPointer(header) + header.byteCount <= end
    }
  }
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
  static var testContentKind: Int32 { get }

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
  /// The type of callback called by ``enumerateTestContent(withHint:_:)``.
  ///
  /// - Parameters:
  ///   - imageAddress: A pointer to the start of the image. This value is _not_
  ///     equal to the value returned from `dlopen()`. On platforms that do not
  ///     support dynamic loading (and so do not have loadable images), the
  ///     value of this argument is unspecified.
  ///   - content: The value produced by the test content record's accessor.
  ///   - flags: Flags associated with `content`. The value of this argument is
  ///     dependent on the type of test content being enumerated.
  ///   - stop: An `inout` boolean variable indicating whether test content
  ///     enumeration should stop after the function returns. Set `stop` to
  ///     `true` to stop test content enumeration.
  typealias TestContentEnumerator = (_ imageAddress: UnsafeRawPointer?, _ content: borrowing TestContentAccessorResult, _ flags: UInt32, _ stop: inout Bool) -> Void

  /// Enumerate all test content headers found in the test content section
  /// described by the given argument that match this ``TestContent`` type.
  ///
  /// - Parameters:
  ///   - sectionBounds: A structure describing the bounds of the test content
  ///     section to walk.
  ///
  /// - Returns: A sequence of tuples. Each tuple contains a pointer to a
  ///   `SWTTestContentHeader` instance and to the base address of the image
  ///   containing that header. Only test content headers matching this
  ///   ``TestContent`` type's requirements are included in the sequence.
  private static func _testContentHeaders(in sectionBounds: SectionBounds) -> some Sequence<UnsafePointer<SWTTestContentHeader>> {
    sectionBounds.testContentHeaders.lazy
      .filter { $0.pointee.n_type == testContentKind }
      .filter { 0 == $0.n_name.map { strcmp($0, _testContentHeaderName) } }
  }

  /// Enumerate all test content headers found in all test content sections
  /// in the current process that match this ``TestContent`` type.
  ///
  /// - Returns: A sequence of tuples. Each tuple contains a pointer to a
  ///   `SWTTestContentHeader` instance and the base address of the image
  ///   containing that header. Only test content headers matching this
  ///   ``TestContent`` type's requirements are included in the sequence.
  private static func _testContentHeaders() -> some Sequence<(imageAddress: UnsafeRawPointer?, header: UnsafePointer<SWTTestContentHeader>)> {
    SectionBounds.allTestContent.lazy.flatMap { sectionBounds in
      Self._testContentHeaders(in: sectionBounds).lazy
        .map { (sectionBounds.imageAddress, $0) }
    }
  }

  /// Enumerate all test content records found in all test content sections in
  /// the current process that match this ``TestContent`` type.
  ///
  /// - Returns: A sequence of tuples. Each tuple contains an `SWTTestContent`
  ///   instance and to the base address of the image containing that test
  ///   content record. Only test content records matching this ``TestContent``
  ///   type's requirements are included in the sequence.
  private static func _testContentRecords() -> some Sequence<(imageAddress: UnsafeRawPointer?, testContent: SWTTestContent)> {
    _testContentHeaders().lazy
      .filter { $0.header.n_descsz >= MemoryLayout<SWTTestContent>.stride }
      .compactMap { imageAddress, header in
        // Load the content from the record via its accessor function. Unaligned
        // because the underlying C structure only guarantees 4-byte alignment
        // even on 64-bit systems.
        let result = header.n_desc?.loadUnaligned(as: SWTTestContent.self)

        // Resign the accessor function (on architectures/platforms with pointer
        // authentication.)
        if var result, let accessor = result.accessor.map(swt_resign) {
          result.accessor = accessor
          return (imageAddress, result)
        }

        return nil
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
    var stop = false
    for (imageAddress, record) in _testContentRecords() {
      if let result = _callAccessor(record.accessor, withHint: hint) {
        // Call the callback.
        body(imageAddress, result, record.flags, &stop)
        if stop {
          break
        }
      }
    }
  }
}
