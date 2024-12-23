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

// MARK: Discoverable types

/// A protocol describing types that can be stored as metadata at compile time
/// and then be discovered at runtime.
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
public protocol Discoverable: ~Copyable {
  /// A unique 32-bit value that identifies instances of this discoverable type
  /// found at runtime by the testing library.
  ///
  /// The value of this property should be unique to this type. To register a
  /// unique kind value, open an issue against the testing library's GitHub
  /// repository.
  ///
  /// This property is not part of the public interface of the testing
  /// library. It may be removed in a future update.
  static var _discoverableKind: Int32 { get }

#if hasFeature(SuppressedAssociatedTypes)
  /// A value to pass to this type's initializer in order to create an instance.
  ///
  /// By default, this type is simply `Self` and the default implementation of
  /// ``init(from:hint:)`` returns its `context` argument verbatim.
  associatedtype DiscoverableContext: ~Copyable = Self
#else
  /// A value to pass to this type's initializer in order to create an instance.
  ///
  /// By default, this type is simply `Self` and the default implementation of
  /// ``init(from:hint:)`` returns its `context` argument verbatim.
  associatedtype DiscoverableContext = Self
#endif

  /// A value to pass to this type's initializer as an optimization hint.
  ///
  /// Values of this type are passed by address to the accessor function emitted
  /// for discoverable values at compile time.
  ///
  /// By default, this type is equal to `Never`, indicating that no hint is
  /// supported by this type.
  associatedtype DiscoverableHint = Never

  /// Initialize an instance of this type with a value resolved by the testing
  /// library at runtime.
  ///
  /// - Parameters:
  ///   - context: The value resolved by the testing library at runtime during
  ///     test content discovery.
  ///   - hint: A "hint" value passed by the code
  ///
  /// The values of `context` and `hint` and their meanings relative to this
  /// type are unspecified by the testing library; this initializer is
  /// responsible for determining the semantic meaning of `context` and `hint`
  /// and how to use them.
  ///
  /// If `context` or `hint` cannot be used to initialize this type, the
  /// initializer should return `nil`.
  init?(from context: consuming DiscoverableContext, hint: DiscoverableHint?) async
}

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension Discoverable where Self: ~Copyable, DiscoverableContext == Self {
  public init?(from context: consuming Self, hint: DiscoverableHint?) async {
    self = context
  }
}

// MARK: - Test content headers

extension UnsafePointer<SWTTestContentHeader> {
  /// The size of the implied `n_name` field, in bytes.
  var n_namesz: Int {
    Int(pointee.n_namesz)
  }

  /// Get the implied `n_name` field.
  ///
  /// If this test content header has no name, or if the name is not
  /// null-terminated, the value of this property is `nil`.
  fileprivate var n_name: UnsafePointer<CChar>? {
    return (self + 1).withMemoryRebound(to: CChar.self, capacity: n_namesz) { name in
      if strnlen(name, n_namesz) >= n_namesz {
        // There is no trailing null byte within the provided length.
        return nil
      }
      return name
    }
  }

  /// The size of the implied `n_name` field, in bytes.
  var n_descsz: Int {
    Int(pointee.n_descsz)
  }

  /// The implied `n_desc` field.
  ///
  /// If this test content header has no description (payload), the value of
  /// this property is `nil`.
  fileprivate var n_desc: UnsafeRawPointer? {
    if n_descsz <= 0 {
      return nil
    }
    return UnsafeRawPointer(self + 1) + swt_alignup(n_namesz, MemoryLayout<UInt32>.alignment)
  }
}

// MARK: - Test content enumeration

@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension Discoverable where Self: ~Copyable {
  /// The type of callback called by ``enumerateTestContent(ofKind:as:_:)``.
  ///
  /// - Parameters:
  ///   - imageAddress: A pointer to the start of the image. This value is _not_
  ///     equal to the value returned from `dlopen()`. On platforms that do not
  ///     support dynamic loading (and so do not have loadable images), the value
  ///     of this argument is unspecified.
  ///   - content: The enumerated test content.
  ///   - flags: Flags associated with `content`. The value of this argument is
  ///     dependent on the type of test content being enumerated.
  ///   - stop: An `inout` boolean variable indicating whether test content
  ///     enumeration should stop after the function returns. Set `stop` to `true`
  ///     to stop test content enumeration.
  public typealias DiscoverableEnumerator = (_ imageAddress: UnsafeRawPointer?, _ content: borrowing Self, _ flags: UInt32, _ stop: inout Bool) -> Void

  /// Enumerate all instances of this type known to Swift and discovered in the
  /// current process at runtime.
  ///
  /// - Parameters:
  ///   - hint: A pointer to a kind-specific hint value. If not `nil`, this
  ///     value is passed as the second argument to each test content record's
  ///     accessor function, allowing that function to determine if its record
  ///     matches before initializing its out-result.
  ///   - body: A function to invoke, once per matching test content record.
  public static func discover(withHint hint: DiscoverableHint? = nil, _ body: DiscoverableEnumerator) async {
    // Get all the test content sections in the process.
    var sectionBoundsCount = 0
    let sectionBounds = swt_copyTestContentSectionBounds(&sectionBoundsCount)
    defer {
      free(sectionBounds)
    }

    // Create a sequence of all the headers across all sections.
    let headers = UnsafeBufferPointer(start: sectionBounds, count: sectionBoundsCount).lazy
      .filter { $0.size > (MemoryLayout<SWTTestContentHeader>.stride + MemoryLayout<SWTTestContent>.stride) }
      .flatMap { sectionBounds in
        let first = (sectionBounds.imageAddress, sectionBounds.start.assumingMemoryBound(to: SWTTestContentHeader.self))
        return sequence(first: first) { imageAddress, header in
          let size = swt_alignup(
            MemoryLayout<SWTTestContentHeader>.stride + swt_alignup(header.n_namesz, MemoryLayout<UInt32>.stride) + header.n_descsz,
            MemoryLayout<Int>.alignment
          );
          let next = (UnsafeRawPointer(header) + size).assumingMemoryBound(to: SWTTestContentHeader.self)
          guard next < sectionBounds.start + sectionBounds.size else {
            return nil
          }
          return (imageAddress, next)
        }
      }

    for (imageAddress, header) in headers {
      // We only care about test content records with the specified kind and the
      // "Swift Testing" name.
      guard header.pointee.n_type == _discoverableKind,
            let n_name = header.n_name, 0 == strcmp(n_name, "Swift Testing") else {
        continue
      }

      // Load the test content record. Unaligned because the underlying C
      // structure only guarantees 4-byte alignment even on 64-bit systems.
      guard let content = header.n_desc?.loadUnaligned(as: SWTTestContent.self),
            let accessor = content.accessor.map(swt_resign) else {
        continue
      }

      let context: DiscoverableContext? = withUnsafeTemporaryAllocation(of: DiscoverableContext.self, capacity: 1) { buffer in
        // Call the accessor function to get the context for the discoverable
        // type (which may well just be the instance of said type.)
        return withUnsafePointer(to: hint) { hint in
          guard accessor(buffer.baseAddress!, hint) else {
            return nil // loop-continue
          }
          return buffer.baseAddress!.move()
        }
      }

      // Call the callback.
      if let context, let instance = await Self(from: context, hint: hint) {
        var stop = false
        body(imageAddress, instance, content.flags, &stop)
        if stop {
          break
        }
      }
    }
  }
}
