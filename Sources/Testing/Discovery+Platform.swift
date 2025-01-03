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
private import SwiftShims

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
}

#if !SWT_NO_DYNAMIC_LINKING
#if SWT_TARGET_OS_APPLE
// MARK: - Apple implementation

/// An array containing all of the test content section bounds known to the
/// testing library.
private let _sectionBounds = Locked<[SectionBounds]>(rawValue: [])

/// A call-once function that initializes `_sectionBounds` and starts listening
/// for loaded Mach headers.
private let _startCollectingSectionBounds: Void = {
  // Ensure _sectionBounds is initialized before we touch libobjc or dyld.
  _sectionBounds.withLock { sectionBounds in
    sectionBounds.reserveCapacity(Int(_dyld_image_count()))
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
    var size = CUnsignedLong(0)
    if let start = getsectiondata(mh, "__DATA_CONST", "__swift5_tests", &size), size > 0 {
      _sectionBounds.withLock { sectionBounds in
        let buffer = UnsafeRawBufferPointer(start: start, count: Int(clamping: size))
        let sb = SectionBounds(imageAddress: mh, buffer: buffer)
        sectionBounds.append(sb)
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

/// The Apple-specific implementation of ``SectionBounds/all``.
///
/// - Returns: An array of structures describing the bounds of all known test
///   content sections in the current process.
private func _testContentSectionBounds() -> [SectionBounds] {
  _startCollectingSectionBounds
  return _sectionBounds.rawValue
}

#elseif os(Linux) || os(FreeBSD) || os(Android)
// MARK: - ELF implementation

extension UnsafePointer<SWTElfWNhdr> {
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

/// All test content headers found in this test content section.
func _noteHeaders(in buffer: UnsafeRawBufferPointer) -> some Sequence<UnsafePointer<SWTElfWNhdr>> {
  let start = buffer.baseAddress!
  let end: UnsafeRawPointer = start + buffer.count
  let firstHeader = start.assumingMemoryBound(to: SWTElfWNhdr.self)

  // Generate an infinite sequence of (possible) header addresses, then prefix
  // it to those that are actually contained within the section. This way we can
  // bounds-check even the first header while maintaining an opaque return type.
  return sequence(first: firstHeader) { header in
    (UnsafeRawPointer(header) + header.byteCount).assumingMemoryBound(to: SWTElfWNhdr.self)
  }.lazy.prefix { header in
    header >= start && header < end
      && (header + 1) <= end
      && UnsafeRawPointer(header) + header.byteCount <= end
  }
}

/// The ELF-specific implementation of ``SectionBounds/all``.
///
/// - Returns: An array of structures describing the bounds of all known test
///   content sections in the current process.
private func _testContentSectionBounds() -> [SectionBounds] {
  var result = [SectionBounds]()

  withUnsafeMutablePointer(to: &result) { result in
    _ = swt_dl_iterate_phdr(result) { dlpi_addr, dlpi_phdr, dlpi_phnum, context in
      let result = context!.assumingMemoryBound(to: [SectionBounds].self)

      let buffer = UnsafeBufferPointer(start: dlpi_phdr, count: dlpi_phnum)
      let sectionBoundsNotes: some Sequence<UnsafePointer<SWTElfWNhdr>> = buffer.lazy
        .filter { $0.p_type == PT_NOTE }
        .map { phdr in
          UnsafeRawBufferPointer(
            start: dlpi_addr + Int(clamping: UInt(clamping: phdr.p_vaddr)),
            count: Int(clamping: phdr.p_memsz)
          )
        }.flatMap(_noteHeaders(in:))
        .filter { $0.pointee.n_type == 0 }
        .filter { 0 == $0.n_name.map { strcmp($0, "swift5_tests") } }

      result.pointee += sectionBoundsNotes.lazy
        .compactMap { $0.n_desc?.assumingMemoryBound(to: UnsafePointer<UnsafeRawPointer>.self) }
        .map { UnsafeRawBufferPointer(start: $0[0], count: $0[1] - $0[0]) }
        .map { SectionBounds(imageAddress: dlpi_addr, buffer: $0) }

      return 0
    }
  }

  return result
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

/// The Windows-specific implementation of ``SectionBounds/all``.
///
/// - Returns: An array of structures describing the bounds of all known test
///   content sections in the current process.
private func _testContentSectionBounds() -> [SectionBounds] {
  HMODULE.all.compactMap { _findSection(named: ".sw5test", in: $0) }
}
#else
/// The fallback implementation of ``SectionBounds/all`` for platforms that
/// support dynamic linking.
///
/// - Returns: The empty array.
private func _testContentSectionBounds() -> [SectionBounds] {
  #warning("Platform-specific implementation missing: Runtime test discovery unavailable (dynamic)")
  return []
}
#endif
#else
// MARK: - Statically-linked implementation

/// The common implementation of ``SectionBounds/all`` for platforms that do not
/// support dynamic linking.
///
/// - Returns: A structure describing the bounds of the test content section
///   contained in the same image as the testing library itself.
private func _testContentSectionBounds() -> CollectionOfOne<SectionBounds> {
  let (sectionBegin, sectionEnd) = SWTTestContentSectionBounds
  let buffer = UnsafeRawBufferPointer(start: n, count: max(0, sectionEnd - sectionBegin))
  let sb = SectionBounds(imageAddress: nil, buffer: buffer)
  return CollectionOfOne(sb)
}
#endif
