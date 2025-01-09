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

  /// All test content section bounds found in the current process.
  static var allTestContent: some RandomAccessCollection<SectionBounds> {
    _testContentSectionBounds()
  }

  /// All type metadata section bounds found in the current process.
  static var allTypeMetadata: some RandomAccessCollection<SectionBounds> {
    _typeMetadataSectionBounds()
  }
}

#if !SWT_NO_DYNAMIC_LINKING
#if SWT_TARGET_OS_APPLE
// MARK: - Apple implementation

/// A type describing the different sections that we collect.
private struct _AllSectionBounds: Sendable {
  /// Test content section bounds.
  var testContent = [SectionBounds]()

  /// Type metadata section bounds.
  var typeMetadata = [SectionBounds]()
}

/// An array containing all of the test content section bounds known to the
/// testing library.
private let _sectionBounds = Locked(rawValue: _AllSectionBounds())

/// A call-once function that initializes `_sectionBounds` and starts listening
/// for loaded Mach headers.
private let _startCollectingSectionBounds: Void = {
  // Ensure _sectionBounds is initialized before we touch libobjc or dyld.
  _sectionBounds.withLock { sectionBounds in
    let imageCount = Int(_dyld_image_count())
    sectionBounds.testContent.reserveCapacity(imageCount)
    sectionBounds.typeMetadata.reserveCapacity(imageCount)
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

    // If this image contains the Swift section we need, acquire the lock and
    // store the section's bounds.
    let testContentSectionBounds: SectionBounds? = {
      var size = CUnsignedLong(0)
      if let start = getsectiondata(mh, "__DATA_CONST", "__swift5_tests", &size), size > 0 {
        let buffer = UnsafeRawBufferPointer(start: start, count: Int(clamping: size))
        return SectionBounds(imageAddress: mh, buffer: buffer)
      }
      return nil
    }()

    let typeMetadataSectionBounds: SectionBounds? = {
      var size = CUnsignedLong(0)
      if let start = getsectiondata(mh, "__TEXT", "__swift5_types", &size), size > 0 {
        let buffer = UnsafeRawBufferPointer(start: start, count: Int(clamping: size))
        return SectionBounds(imageAddress: mh, buffer: buffer)
      }
      return nil
    }()

    if testContentSectionBounds != nil || typeMetadataSectionBounds != nil {
      _sectionBounds.withLock { sectionBounds in
        if let testContentSectionBounds {
          sectionBounds.testContent.append(testContentSectionBounds)
        }
        if let typeMetadataSectionBounds {
          sectionBounds.typeMetadata.append(typeMetadataSectionBounds)
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
    addSectionBounds(from: mh)
  }
#endif
}()

/// The Apple-specific implementation of ``SectionBounds/allTestContent``.
///
/// - Returns: An array of structures describing the bounds of all known test
///   content sections in the current process.
private func _testContentSectionBounds() -> [SectionBounds] {
  _startCollectingSectionBounds
  return _sectionBounds.rawValue.testContent
}

/// The Apple-specific implementation of ``SectionBounds/allTypeMetadata``.
///
/// - Returns: An array of structures describing the bounds of all known type
///   metadata sections in the current process.
private func _typeMetadataSectionBounds() -> [SectionBounds] {
  _startCollectingSectionBounds
  return _sectionBounds.rawValue.typeMetadata
}

#elseif os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Android)
// MARK: - ELF implementation

private import SwiftShims // For MetadataSections

/// Get all Swift metadata sections of a given name that have been loaded into
/// the current process.
///
/// - Parameters:
///   - sectionRangeKeyPath: A key path to the field of ``MetadataSections``
///     containing the bounds of the section of interest.
///
/// - Returns: An array of structures describing the bounds of all known
///   sections in the current process matching `sectionRangeKeyPath`.
private func _sectionBounds(for sectionRangeKeyPath: KeyPath<MetadataSections, MetadataSectionRange>) -> [SectionBounds] {
  var result = [SectionBounds]()

  withUnsafeMutablePointer(to: &result) { result in
    swift_enumerateAllMetadataSections({ sections, context in
      let version = sections.load(as: UInt.self)
      guard sectionRangeKeyPath != \.swift5_tests || version >= 4 else {
        // This structure is too old to contain the swift5_tests field.
        return true
      }

      let range = sections.load(as: MetadataSections.self)[keyPath: sectionRangeKeyPath]
      let start = UnsafeRawPointer(bitPattern: range.start)
      let size = Int(clamping: range.length)
      if let start, size > 0 {
        let buffer = UnsafeRawBufferPointer(start: start, count: size)
        let sb = SectionBounds(imageAddress: sections.baseAddress, buffer: buffer)

        let result = context.assumingMemoryBound(to: [SectionBounds].self)
        result.pointee.append(sb)
      }

      return true
    }, result)
  }

  return result
}

/// The ELF-specific implementation of ``SectionBounds/allTestContent``.
///
/// - Returns: An array of structures describing the bounds of all known test
///   content sections in the current process.
private func _testContentSectionBounds() -> [SectionBounds] {
  _sectionBounds(for: \.swift5_tests)
}

/// The ELF-specific implementation of ``SectionBounds/allTypeMetadata``.
///
/// - Returns: An array of structures describing the bounds of all known type
///   metadata sections in the current process.
private func _typeMetadataSectionBounds() -> [SectionBounds] {
  _sectionBounds(for: \.swift5_type_metadata)
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

/// The Windows-specific implementation of ``SectionBounds/allTestContent``.
///
/// - Returns: An array of structures describing the bounds of all known test
///   content sections in the current process.
private func _testContentSectionBounds() -> [SectionBounds] {
  HMODULE.all.compactMap { _findSection(named: ".sw5test", in: $0) }
}

/// The Windows-specific implementation of ``SectionBounds/allTypeMetadata``.
///
/// - Returns: An array of structures describing the bounds of all known type
///   metadata sections in the current process.
private func _typeMetadataSectionBounds() -> [SectionBounds] {
  HMODULE.all.compactMap { _findSection(named: ".sw5tymd", in: $0) }
}
#else
/// The fallback implementation of ``SectionBounds/allTestContent`` for
/// platforms that support dynamic linking.
///
/// - Returns: The empty array.
private func _testContentSectionBounds() -> [SectionBounds] {
  #warning("Platform-specific implementation missing: Runtime test discovery unavailable (dynamic)")
  return []
}

/// The fallback implementation of ``SectionBounds/allTypeMetadata`` for
/// platforms that support dynamic linking.
///
/// - Returns: The empty array.
private func _typeMetadataSectionBounds() -> [SectionBounds] {
#warning("Platform-specific implementation missing: Runtime test discovery unavailable (dynamic)")
  return []
}
#endif
#else
// MARK: - Statically-linked implementation

/// The common implementation of ``SectionBounds/allTestContent`` for platforms
/// that do not support dynamic linking.
///
/// - Returns: A structure describing the bounds of the test content section
///   contained in the same image as the testing library itself.
private func _testContentSectionBounds() -> CollectionOfOne<SectionBounds> {
  let (sectionBegin, sectionEnd) = SWTTestContentSectionBounds
  let buffer = UnsafeRawBufferPointer(start: sectionBegin, count: max(0, sectionEnd - sectionBegin))
  let sb = SectionBounds(imageAddress: nil, buffer: buffer)
  return CollectionOfOne(sb)
}

/// The common implementation of ``SectionBounds/allTypeMetadata`` for platforms
/// that do not support dynamic linking.
///
/// - Returns: A structure describing the bounds of the type metadata section
///   contained in the same image as the testing library itself.
private func _typeMetadataSectionBounds() -> CollectionOfOne<SectionBounds> {
  let (sectionBegin, sectionEnd) = SWTTypeMetadataSectionBounds
  let buffer = UnsafeRawBufferPointer(start: sectionBegin, count: max(0, sectionEnd - sectionBegin))
  let sb = SectionBounds(imageAddress: nil, buffer: buffer)
  return CollectionOfOne(sb)
}
#endif
