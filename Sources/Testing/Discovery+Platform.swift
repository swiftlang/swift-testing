//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals

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

    /// The type metadata section.
    case typeMetadata
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

/// An array containing all of the test content section bounds known to the
/// testing library.
private let _sectionBounds = Locked<[SectionBounds.Kind: [SectionBounds]]>()

/// A call-once function that initializes `_sectionBounds` and starts listening
/// for loaded Mach headers.
private let _startCollectingSectionBounds: Void = {
  // Ensure _sectionBounds is initialized before we touch libobjc or dyld.
  _sectionBounds.withLock { sectionBounds in
    let imageCount = Int(clamping: _dyld_image_count())
    for kind in SectionBounds.Kind.allCases {
      sectionBounds[kind, default: []].reserveCapacity(imageCount)
    }
  }

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
    func findSectionBounds(forSectionNamed segmentName: String, _ sectionName: String, ofKind kind: SectionBounds.Kind) {
      var size = CUnsignedLong(0)
      if let start = getsectiondata(mh, segmentName, sectionName, &size), size > 0 {
        let buffer = UnsafeRawBufferPointer(start: start, count: Int(clamping: size))
        let sb = SectionBounds(imageAddress: mh, buffer: buffer)
        _sectionBounds.withLock { sectionBounds in
          sectionBounds[kind]!.append(sb)
        }
      }
    }
    findSectionBounds(forSectionNamed: "__DATA_CONST", "__swift5_tests", ofKind: .testContent)
    findSectionBounds(forSectionNamed: "__TEXT", "__swift5_types", ofKind: .typeMetadata)
  }

#if _runtime(_ObjC)
  objc_addLoadImageFunc { mh in
    addSectionBounds(from: mh)
  }
#else
  _dyld_register_func_for_add_image { mh, _ in
    addSectionBounds(from: mh)
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
  return _sectionBounds.rawValue[kind]!
}

#elseif os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android)
// MARK: - ELF implementation

private import SwiftShims // For MetadataSections

/// A function exported by the Swift runtime that enumerates all metadata
/// sections loaded into the current process.
///
/// This function is needed on ELF-based platforms because they do not preserve
/// section information that we can discover at runtime.
@_silgen_name("swift_enumerateAllMetadataSections")
private func swift_enumerateAllMetadataSections(
  _ body: @convention(c) (_ sections: UnsafePointer<MetadataSections>, _ context: UnsafeMutableRawPointer) -> CBool,
  _ context: UnsafeMutableRawPointer
)

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

      guard context.pointee.kind != .testContent || sections.pointee.version >= 4 else {
        // This structure is too old to contain the swift5_tests field.
        return true
      }

      let range = switch context.pointee.kind {
      case .testContent:
        sections.pointee.swift5_tests
      case .typeMetadata:
        sections.pointee.swift5_type_metadata
      }
      let start = UnsafeRawPointer(bitPattern: range.start)
      let size = Int(clamping: range.length)
      if let start, size > 0 {
        let buffer = UnsafeRawBufferPointer(start: start, count: size)
        let sb = SectionBounds(imageAddress: sections.pointee.baseAddress, buffer: buffer)

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
  case .typeMetadata:
    ".sw5tymd"
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
private func _sectionBounds(_ kind: SectionBounds.Kind) -> [SectionBounds] {
  #warning("Platform-specific implementation missing: Runtime test discovery unavailable (dynamic)")
  return []
}
#endif
#else
// MARK: - Statically-linked implementation

/// A type that represents a section boundary symbol created at link-time.
private struct _SectionBound: ~Copyable {
  /// An "unreal" stored property that ensures the layout of this type is
  /// at least naturally aligned and has a non-zero size/stride.
  ///
  /// This property does not actually exist, but it is necessary to convince the
  /// Swift compiler that an instance of this type has an in-memory presence.
  ///
  /// - Warning: The value of this property is undefined.
  private var _ensureLayout: Int = 0

  /// Get the address of this instance.
  ///
  /// - Returns: The address of `self`.
  ///
  /// This function does not actually mutate `self`, but it is necessary to
  /// declare it as mutating to avoid temporarily copying `self` and getting the
  /// address of the copy (which can happen even to move-only types so long as
  /// the pointer does not escape.)
  ///
  /// - Warning: The implementation of this function is inherently unsafe, and
  ///   only works as intended under very narrow conditions.
  mutating func unsafeAddress() -> UnsafeRawPointer {
    withUnsafeMutablePointer(to: &self) { UnsafeRawPointer($0) }
  }
}

#if SWT_TARGET_OS_APPLE
@_silgen_name(raw: "section$start$__DATA_CONST$__swift5_tests")
private nonisolated(unsafe) var _testContentSectionBegin: _SectionBound
@_silgen_name(raw: "section$end$__DATA_CONST$__swift5_tests")
private nonisolated(unsafe) var _testContentSectionEnd: _SectionBound

@_silgen_name(raw: "section$start$__TEXT$__swift5_types")
private nonisolated(unsafe) var _typeMetadataSectionBegin: _SectionBound
@_silgen_name(raw: "section$end$__TEXT$__swift5_types")
private nonisolated(unsafe) var _typeMetadataSectionEnd: _SectionBound
#elseif os(WASI)
@_silgen_name(raw: "__start_swift5_tests")
private nonisolated(unsafe) var _testContentSectionBegin: _SectionBound
@_silgen_name(raw: "__stop_swift5_tests")
private nonisolated(unsafe) var _testContentSectionEnd: _SectionBound

@_silgen_name(raw: "__start_swift5_type_metadata")
private nonisolated(unsafe) var _typeMetadataSectionBegin: _SectionBound
@_silgen_name(raw: "__stop_swift5_type_metadata")
private nonisolated(unsafe) var _typeMetadataSectionEnd: _SectionBound
#else
#warning("Platform-specific implementation missing: Runtime test discovery unavailable (static)")
private nonisolated(unsafe) var _testContentSectionBegin = _SectionBound()
private nonisolated(unsafe) var _testContentSectionEnd: _SectionBound {
  _read { yield _testContentSectionBegin }
  _modify { yield &_testContentSectionBegin }
}

private nonisolated(unsafe) var _typeMetadataSectionBegin = _SectionBound()
private nonisolated(unsafe) var _typeMetadataSectionEnd: _SectionBound {
  _read { yield _testContentSectionBegin }
  _modify { yield &_testContentSectionBegin }
}
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
  let (sectionBegin, sectionEnd) = switch kind {
  case .testContent:
    (_testContentSectionBegin.unsafeAddress(), _testContentSectionEnd.unsafeAddress())
  case .typeMetadata:
    (_typeMetadataSectionBegin.unsafeAddress(), _typeMetadataSectionEnd.unsafeAddress())
  }
  let buffer = UnsafeRawBufferPointer(start: sectionBegin, count: max(0, sectionEnd - sectionBegin))
  let sb = SectionBounds(imageAddress: nil, buffer: buffer)
  return CollectionOfOne(sb)
}
#endif
