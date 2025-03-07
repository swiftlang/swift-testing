//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

// MARK: Low-level structure

/// The type of the accessor function used to access a test content record.
///
/// - Parameters:
///   - outValue: A pointer to uninitialized memory large enough to contain the
///     corresponding test content record's value.
///   - type: A pointer to the expected type of `outValue`. Use `load(as:)` to
///     get the Swift type, not `unsafeBitCast(_:to:)`.
///   - hint: An optional pointer to a hint value.
///
/// - Returns: Whether or not `outValue` was initialized. The caller is
///   responsible for deinitializing `outValue` if it was initialized.
private typealias _TestContentRecordAccessor = @convention(c) (
  _ outValue: UnsafeMutableRawPointer,
  _ type: UnsafeRawPointer,
  _ hint: UnsafeRawPointer?
) -> CBool

/// The content of a test content record.
///
/// - Parameters:
///   - kind: The kind of this record.
///   - reserved1: Reserved for future use.
///   - accessor: A function which, when called, produces the test content.
///   - context: Kind-specific context for this record.
///   - reserved2: Reserved for future use.
private typealias _TestContentRecord = (
  kind: UInt32,
  reserved1: UInt32,
  accessor: _TestContentRecordAccessor?,
  context: UInt,
  reserved2: UInt
)

extension DiscoverableAsTestContent where Self: ~Copyable {
  /// Check that the layout of this structure in memory matches its expected
  /// layout in the test content section.
  ///
  /// It is not currently possible to perform this validation at compile time.
  /// ([swift-#79667](https://github.com/swiftlang/swift/issues/79667))
  fileprivate static func validateMemoryLayout() {
    precondition(MemoryLayout<TestContentContext>.stride == MemoryLayout<UInt>.stride, "'\(self).TestContentContext' aka '\(TestContentContext.self)' must have the same stride as 'UInt'.")
    precondition(MemoryLayout<TestContentContext>.alignment == MemoryLayout<UInt>.alignment, "'\(self).TestContentContext' aka '\(TestContentContext.self)' must have the same alignment as 'UInt'.")
  }
}

// MARK: - Individual test content records

/// A type describing a test content record of a particular (known) type.
///
/// Instances of this type can be created by calling
/// ``DiscoverableAsTestContent/allTestContentRecords()`` on a type that
/// conforms to ``DiscoverableAsTestContent``.
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public struct TestContentRecord<T> where T: DiscoverableAsTestContent & ~Copyable {
  /// The base address of the image containing this instance, if known.
  ///
  /// The type of this pointer is platform-dependent:
  ///
  /// | Platform | Pointer Type |
  /// |-|-|
  /// | macOS, iOS, watchOS, tvOS, visionOS | `UnsafePointer<mach_header64>` |
  /// | Linux, FreeBSD, Android | `UnsafePointer<ElfW_Ehdr>` |
  /// | OpenBSD | `UnsafePointer<Elf_Ehdr>` |
  /// | Windows | `HMODULE` |
  ///
  /// On platforms such as WASI that statically link to the testing library, the
  /// value of this property is always `nil`.
  ///
  /// - Note: The value of this property is distinct from the pointer returned
  ///   by `dlopen()` (on platforms that have that function) and cannot be used
  ///   with interfaces such as `dlsym()` that expect such a pointer.
  public private(set) nonisolated(unsafe) var imageAddress: UnsafeRawPointer?

  /// The address of the underlying test content record loaded from a metadata
  /// section.
  private nonisolated(unsafe) var _recordAddress: UnsafePointer<_TestContentRecord>

  fileprivate init(imageAddress: UnsafeRawPointer?, recordAddress: UnsafePointer<_TestContentRecord>) {
    self.imageAddress = imageAddress
    self._recordAddress = recordAddress
  }

  /// The type of the ``context`` property.
  public typealias Context = T.TestContentContext

  /// The context of this test content record.
  public var context: Context {
    T.validateMemoryLayout()
    return withUnsafeBytes(of: _recordAddress.pointee.context) { context in
      context.load(as: Context.self)
    }
  }

  /// The type of the `hint` argument to ``load(withHint:)``.
  public typealias Hint = T.TestContentAccessorHint

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
  /// The result of this function is not cached. If this function is called more
  /// than once on the same instance, the testing library calls the underlying
  /// test content record's accessor function each time.
  public func load(withHint hint: Hint? = nil) -> T? {
    guard let accessor = _recordAddress.pointee.accessor else {
      return nil
    }

    return withUnsafePointer(to: T.self) { type in
      withUnsafeTemporaryAllocation(of: T.self, capacity: 1) { buffer in
        let initialized = if let hint {
          withUnsafePointer(to: hint) { hint in
            accessor(buffer.baseAddress!, type, hint)
          }
        } else {
          accessor(buffer.baseAddress!, type, nil)
        }
        guard initialized else {
          return nil
        }
        return buffer.baseAddress!.move()
      }
    }
  }
}

// Test content sections effectively exist outside any Swift isolation context.
// We can only be (reasonably) sure that the data backing the test content
// record is concurrency-safe if all fields in the test content record are. The
// pointers stored in this structure are read-only and come from a loaded image,
// and all fields of `_TestContentRecord` as we define it are sendable. However,
// the custom `Context` type may or may not be sendable (it could validly be a
// pointer to more data, for instance.)
extension TestContentRecord: Sendable where Context: Sendable {}

// MARK: - CustomStringConvertible

extension TestContentRecord: CustomStringConvertible {
  /// This test content type's kind value as an ASCII string (of the form
  /// `"abcd"`) if it looks like it might be a [FourCC](https://en.wikipedia.org/wiki/FourCC)
  /// value, or `nil` if not.
  private static var _asciiKind: String? {
    return withUnsafeBytes(of: T.testContentKind.bigEndian) { bytes in
      if bytes.allSatisfy(Unicode.ASCII.isASCII) {
        let characters = String(decoding: bytes, as: Unicode.ASCII.self)
        let allAlphanumeric = characters.allSatisfy { $0.isLetter || $0.isWholeNumber }
        if allAlphanumeric {
          return characters
        }
      }
      return nil
    }
  }

  public var description: String {
    let typeName = String(describing: Self.self)
    let hexKind = "0x" + String(T.testContentKind, radix: 16)
    let kind = Self._asciiKind.map { asciiKind in
      "'\(asciiKind)' (\(hexKind))"
    } ?? hexKind
    let recordAddress = imageAddress.map { imageAddress in
      let recordAddressDelta = UnsafeRawPointer(_recordAddress) - imageAddress
      return "\(imageAddress)+0x\(String(recordAddressDelta, radix: 16))"
    } ?? "\(_recordAddress)"
    return "<\(typeName) \(recordAddress)> { kind: \(kind), context: \(context) }"
  }
}

// MARK: - Enumeration of test content records

extension DiscoverableAsTestContent where Self: ~Copyable {
  /// Get all test content of this type known to Swift and found in the current
  /// process.
  ///
  /// - Returns: A sequence of instances of ``TestContentRecord``. Only test
  ///   content records matching this ``TestContent`` type's requirements are
  ///   included in the sequence.
  ///
  /// @Comment {
  ///   - Bug: This function returns an instance of `AnySequence` instead of an
  ///     opaque type due to a compiler crash. ([143080508](rdar://143080508))
  /// }
  public static func allTestContentRecords() -> AnySequence<TestContentRecord<Self>> {
    validateMemoryLayout()
    let result = SectionBounds.all(.testContent).lazy.flatMap { sb in
      sb.buffer.withMemoryRebound(to: _TestContentRecord.self) { records in
        (0 ..< records.count).lazy
          .map { (records.baseAddress! + $0) as UnsafePointer<_TestContentRecord> }
          .filter { $0.pointee.kind == testContentKind }
          .map { TestContentRecord<Self>(imageAddress: sb.imageAddress, recordAddress: $0) }
      }
    }
    return AnySequence(result)
  }
}

// MARK: - Legacy test content discovery

private import _TestingInternals

/// Get all types known to Swift found in the current process whose names
/// contain a given substring.
///
/// - Parameters:
///   - nameSubstring: A string which the names of matching classes all contain.
///
/// - Returns: A sequence of Swift types whose names contain `nameSubstring`.
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
@available(swift, deprecated: 100000.0, message: "Do not adopt this functionality in new code. It will be removed in a future release.")
public func types(withNamesContaining nameSubstring: String) -> some Sequence<Any.Type> {
  SectionBounds.all(.typeMetadata).lazy.flatMap { sb in
    stride(from: sb.buffer.baseAddress!, to: sb.buffer.baseAddress! + sb.buffer.count, by: SWTTypeMetadataRecordByteCount).lazy
      .compactMap { swt_getType(fromTypeMetadataRecord: $0, ifNameContains: nameSubstring) }
      .map { unsafeBitCast($0, to: Any.Type.self) }
  }
}
