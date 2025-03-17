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
#if _runtime(_ObjC)
private import ObjectiveC
#endif

/// A structure describing the bounds of a Swift metadata section.
struct SectionBounds: Sendable {
  /// The base address of the image containing the section, if known.
  nonisolated(unsafe) var imageAddress: UnsafeRawPointer?

  /// The in-memory representation of the section.
  nonisolated(unsafe) var buffer: UnsafeRawBufferPointer

  /// An enumeration describing the different sections discoverable by the
  /// testing library.
  enum Kind: Equatable, Hashable, CaseIterable {
    /// The test content metadata section.
    case testContent

#if !SWT_NO_LEGACY_TEST_DISCOVERY
    /// The type metadata section.
    case typeMetadata
#endif
  }

  /// All section bounds of the given kind found in the current process.
  ///
  /// - Parameters:
  ///   - kind: Which kind of metadata section to return.
  ///
  /// - Returns: A sequence of structures describing the bounds of metadata
  ///   sections of the given kind found in the current process.
  static func all(_ kind: Kind) -> some Sequence<SectionBounds> {
    _sectionBounds(kind)
  }
}

#if !SWT_NO_DYNAMIC_LINKING
#if SWT_TARGET_OS_APPLE
// MARK: - Apple implementation

extension SectionBounds.Kind {
  /// The Mach-O segment and section name for this instance as a pair of
  /// null-terminated UTF-8 C strings and pass them to a function.
  ///
  /// The values of this property within this function are instances of
  /// `StaticString` rather than `String` because the latter's inner storage is
  /// sometimes Objective-C-backed and touching it here can cause a recursive
  /// access to an internal libobjc lock, whereas `StaticString`'s internal
  /// storage is immediately available.
  fileprivate var segmentAndSectionName: (segmentName: StaticString, sectionName: StaticString) {
    switch self {
    case .testContent:
      ("__DATA_CONST", "__swift5_tests")
#if !SWT_NO_LEGACY_TEST_DISCOVERY
    case .typeMetadata:
      ("__TEXT", "__swift5_types")
#endif
    }
  }
}

/// An array containing all of the test content section bounds known to the
/// testing library.
private nonisolated(unsafe) let _sectionBounds = {
  let result = ManagedBuffer<[SectionBounds.Kind: [SectionBounds]], pthread_mutex_t>.create(
    minimumCapacity: 1,
    makingHeaderWith: { _ in [:] }
  )

  result.withUnsafeMutablePointers { sectionBounds, lock in
    _ = pthread_mutex_init(lock, nil)

    let imageCount = Int(clamping: _dyld_image_count())
    for kind in SectionBounds.Kind.allCases {
      sectionBounds.pointee[kind, default: []].reserveCapacity(imageCount)
    }
  }

  return result
}()

/// A call-once function that initializes `_sectionBounds` and starts listening
/// for loaded Mach headers.
private let _startCollectingSectionBounds: Void = {
  // Ensure _sectionBounds is initialized before we touch libobjc or dyld.
  _ = _sectionBounds

  func addSectionBounds(from mh: UnsafePointer<mach_header>) {
#if _pointerBitWidth(_64)
    let mh = UnsafeRawPointer(mh).assumingMemoryBound(to: mach_header_64.self)
#endif

    // Ignore this Mach header if it is in the shared cache. On platforms that
    // support it (Darwin), most system images are contained in this range.
    // System images can be expected not to contain test declarations, so we
    // don't need to walk them.
    guard 0 == mh.pointee.flags & MH_DYLIB_IN_CACHE else {
      return
    }

    // If this image contains the Swift section(s) we need, acquire the lock and
    // store the section's bounds.
    for kind in SectionBounds.Kind.allCases {
      let (segmentName, sectionName) = kind.segmentAndSectionName
      var size = CUnsignedLong(0)
      if let start = getsectiondata(mh, segmentName.utf8Start, sectionName.utf8Start, &size), size > 0 {
        let buffer = UnsafeRawBufferPointer(start: start, count: Int(clamping: size))
        let sb = SectionBounds(imageAddress: mh, buffer: buffer)
        _sectionBounds.withUnsafeMutablePointers { sectionBounds, lock in
          pthread_mutex_lock(lock)
          defer {
            pthread_mutex_unlock(lock)
          }
          sectionBounds.pointee[kind]!.append(sb)
        }
      }
    }
  }

#if _runtime(_ObjC)
  objc_addLoadImageFunc { mh in
    addSectionBounds(from: mh)
  }
#else
  _dyld_register_func_for_add_image { mh, _ in
    addSectionBounds(from: mh!)
  }
#endif
}()

/// The Apple-specific implementation of ``SectionBounds/all(_:)``.
///
/// - Parameters:
///   - kind: Which kind of metadata section to return.
///
/// - Returns: An array of structures describing the bounds of all known test
///   content sections in the current process.
private func _sectionBounds(_ kind: SectionBounds.Kind) -> [SectionBounds] {
  _startCollectingSectionBounds
  return _sectionBounds.withUnsafeMutablePointers { sectionBounds, lock in
    pthread_mutex_lock(lock)
    defer {
      pthread_mutex_unlock(lock)
    }
    return sectionBounds.pointee[kind]!
  }
}

#elseif os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android)
// MARK: - ELF implementation

private import SwiftShims // For MetadataSections

/// The ELF-specific implementation of ``SectionBounds/all(_:)``.
///
/// - Parameters:
///   - kind: Which kind of metadata section to return.
///
/// - Returns: An array of structures describing the bounds of all known test
///   content sections in the current process.
private func _sectionBounds(_ kind: SectionBounds.Kind) -> [SectionBounds] {
  struct Context {
    var kind: SectionBounds.Kind
    var result = [SectionBounds]()
  }
  var context = Context(kind: kind)

  withUnsafeMutablePointer(to: &context) { context in
    swift_enumerateAllMetadataSections({ sections, context in
      let context = context.assumingMemoryBound(to: Context.self)

      let version = sections.load(as: UInt.self)
      guard context.pointee.kind != .testContent || version >= 4 else {
        // This structure is too old to contain the swift5_tests field.
        return true
      }
      let sections = sections.load(as: MetadataSections.self)

      let range = switch context.pointee.kind {
      case .testContent:
        sections.swift5_tests
#if !SWT_NO_LEGACY_TEST_DISCOVERY
      case .typeMetadata:
        sections.swift5_type_metadata
#endif
      }
      let start = UnsafeRawPointer(bitPattern: range.start)
      let size = Int(clamping: range.length)
      if let start, size > 0 {
        let buffer = UnsafeRawBufferPointer(start: start, count: size)
        let sb = SectionBounds(imageAddress: sections.baseAddress, buffer: buffer)

        context.pointee.result.append(sb)
      }

      return true
    }, context)
  }

  return context.result
}

#elseif os(Windows)
// MARK: - Windows implementation

/// Find the section with the given name in the given module.
///
/// - Parameters:
///   - sectionName: The name of the section to look for. Long section names are
///     not supported.
///   - hModule: The module to inspect.
///
/// - Returns: A structure describing the given section, or `nil` if the section
///   could not be found.
private func _findSection(named sectionName: String, in hModule: HMODULE) -> SectionBounds? {
  hModule.withNTHeader { ntHeader in
    guard let ntHeader else {
      return nil
    }

    let sectionHeaders = UnsafeBufferPointer(
      start: swt_IMAGE_FIRST_SECTION(ntHeader),
      count: Int(clamping: max(0, ntHeader.pointee.FileHeader.NumberOfSections))
    )
    return sectionHeaders.lazy
      .filter { sectionHeader in
        // FIXME: Handle longer names ("/%u") from string table
        withUnsafeBytes(of: sectionHeader.Name) { thisSectionName in
          0 == strncmp(sectionName, thisSectionName.baseAddress!, Int(IMAGE_SIZEOF_SHORT_NAME))
        }
      }.compactMap { sectionHeader in
        guard let virtualAddress = Int(exactly: sectionHeader.VirtualAddress), virtualAddress > 0 else {
          return nil
        }

        var buffer = UnsafeRawBufferPointer(
          start: UnsafeRawPointer(hModule) + virtualAddress,
          count: Int(clamping: min(max(0, sectionHeader.Misc.VirtualSize), max(0, sectionHeader.SizeOfRawData)))
        )
        guard buffer.count > 2 * MemoryLayout<UInt>.stride else {
          return nil
        }

        // Skip over the leading and trailing zeroed uintptr_t values. These
        // values are always emitted by SwiftRT-COFF.cpp into all Swift images.
#if DEBUG
        let firstPointerValue = buffer.baseAddress!.loadUnaligned(as: UInt.self)
        assert(firstPointerValue == 0, "First pointer-width value in section '\(sectionName)' at \(buffer.baseAddress!) was expected to equal 0 (found \(firstPointerValue) instead)")
        let lastPointerValue = ((buffer.baseAddress! + buffer.count) - MemoryLayout<UInt>.stride).loadUnaligned(as: UInt.self)
        assert(lastPointerValue == 0, "Last pointer-width value in section '\(sectionName)' at \(buffer.baseAddress!) was expected to equal 0 (found \(lastPointerValue) instead)")
#endif
        buffer = UnsafeRawBufferPointer(
          rebasing: buffer
            .dropFirst(MemoryLayout<UInt>.stride)
            .dropLast(MemoryLayout<UInt>.stride)
        )

        return SectionBounds(imageAddress: hModule, buffer: buffer)
      }.first
  }
}

/// The Windows-specific implementation of ``SectionBounds/all(_:)``.
///
/// - Parameters:
///   - kind: Which kind of metadata section to return.
///
/// - Returns: An array of structures describing the bounds of all known test
///   content sections in the current process.
private func _sectionBounds(_ kind: SectionBounds.Kind) -> some Sequence<SectionBounds> {
  let sectionName = switch kind {
  case .testContent:
    ".sw5test"
#if !SWT_NO_LEGACY_TEST_DISCOVERY
  case .typeMetadata:
    ".sw5tymd"
#endif
  }
  return HMODULE.all.lazy.compactMap { _findSection(named: sectionName, in: $0) }
}
#else
/// The fallback implementation of ``SectionBounds/all(_:)`` for platforms that
/// support dynamic linking.
///
/// - Parameters:
///   - kind: Ignored.
///
/// - Returns: The empty array.
private func _sectionBounds(_ kind: SectionBounds.Kind) -> EmptyCollection<SectionBounds> {
  #warning("Platform-specific implementation missing: Runtime test discovery unavailable (dynamic)")
  return EmptyCollection()
}
#endif
#else
// MARK: - Statically-linked implementation

/// A type representing the upper or lower bound of a metadata section.
///
/// This type uses the experimental `@_rawLayout` attribute to ensure that
/// instances have fixed addresses. Use the `..<` operator to get a buffer
/// pointer from two instances of this type.
///
/// On platforms that use static linkage and have well-defined bounds symbols,
/// those symbols are imported into Swift below using `@_silgen_name`, another
/// experimental attribute.
@_rawLayout(like: CChar) private struct _SectionBound: @unchecked Sendable, ~Copyable {
  static func ..<(lhs: borrowing Self, rhs: borrowing Self) -> UnsafeRawBufferPointer {
    withUnsafePointer(to: lhs) { lhs in
      withUnsafePointer(to: rhs) { rhs in
        UnsafeRawBufferPointer(start: lhs, count: UnsafeRawPointer(rhs) - UnsafeRawPointer(lhs))
      }
    }
  }
}

#if SWT_TARGET_OS_APPLE
@_silgen_name(raw: "section$start$__DATA_CONST$__swift5_tests") private let _testContentSectionBegin: _SectionBound
@_silgen_name(raw: "section$end$__DATA_CONST$__swift5_tests") private let _testContentSectionEnd: _SectionBound
#if !SWT_NO_LEGACY_TEST_DISCOVERY
@_silgen_name(raw: "section$start$__TEXT$__swift5_types") private let _typeMetadataSectionBegin: _SectionBound
@_silgen_name(raw: "section$end$__TEXT$__swift5_types") private let _typeMetadataSectionEnd: _SectionBound
#endif
#elseif os(WASI)
@_silgen_name(raw: "__start_swift5_tests") private let _testContentSectionBegin: _SectionBound
@_silgen_name(raw: "__stop_swift5_tests") private let _testContentSectionEnd: _SectionBound
#if !SWT_NO_LEGACY_TEST_DISCOVERY
@_silgen_name(raw: "__start_swift5_type_metadata") private let _typeMetadataSectionBegin: _SectionBound
@_silgen_name(raw: "__stop_swift5_type_metadata") private let _typeMetadataSectionEnd: _SectionBound
#endif
#else
#warning("Platform-specific implementation missing: Runtime test discovery unavailable (static)")
private let _testContentSectionBegin = _SectionBound()
private var _testContentSectionEnd: _SectionBound { _read { yield _testContentSectionBegin } }
#if !SWT_NO_LEGACY_TEST_DISCOVERY
private let _typeMetadataSectionBegin = _SectionBound()
private var _typeMetadataSectionEnd: _SectionBound { _read { yield _typeMetadataSectionBegin } }
#endif
#endif

/// The common implementation of ``SectionBounds/all(_:)`` for platforms that do
/// not support dynamic linking.
///
/// - Parameters:
///   - kind: Which kind of metadata section to return.
///
/// - Returns: A structure describing the bounds of the type metadata section
///   contained in the same image as the testing library itself.
private func _sectionBounds(_ kind: SectionBounds.Kind) -> CollectionOfOne<SectionBounds> {
  let buffer = switch kind {
  case .testContent:
    _testContentSectionBegin ..< _testContentSectionEnd
  case .typeMetadata:
    _typeMetadataSectionBegin ..< _typeMetadataSectionEnd
  }
  let sb = SectionBounds(imageAddress: nil, buffer: buffer)
  return CollectionOfOne(sb)
}
#endif
