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

  /// The base address of the section.
  nonisolated(unsafe) var start: UnsafeRawPointer

  /// The size of the section in bytes.
  var size: Int

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
        sectionBounds.append(SectionBounds(imageAddress: mh, start: start, size: Int(bitPattern: size)))
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

/// The ELF-specific implementation of ``SectionBounds/all``.
///
/// - Returns: An array of structures describing the bounds of all known test
///   content sections in the current process.
private func _testContentSectionBounds() -> [SectionBounds] {
  var result = [SectionBounds]()

  withUnsafeMutablePointer(to: &result) { result in
    _ = swt_dl_iterate_phdr(result) { dlpi_addr, dlpi_phdr, dlpi_phnum, context in
      print("PHDR IMAGE ADDRESS:", dlpi_addr)
      let sectionBounds = context!.assumingMemoryBound(to: [SectionBounds].self)
      let phdrs = UnsafeBufferPointer(start: dlpi_phdr, count: Int(clamping: dlpi_phnum))

      sectionBounds.pointee += phdrs.lazy
        .filter { $0.p_type == PT_NOTE }
        .map { phdr in
          SectionBounds(
            imageAddress: dlpi_addr,
            start: dlpi_addr + Int(bitPattern: UInt(phdr.p_vaddr)),
            size: Int(phdr.p_memsz)
          )
        }

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
        var sb = SectionBounds(
          imageAddress: hModule,
          start: UnsafeRawPointer(hModule) + virtualAddress,
          size: Int(clamping: min(max(0, sectionHeader.Misc.VirtualSize), max(0, sectionHeader.SizeOfRawData)))
        )

        // Skip over the leading and trailing zeroed uintptr_t values. These
        // values are always emitted by SwiftRT-COFF.cpp into all Swift images.
        guard sb.size > 2 * MemoryLayout<UInt>.stride else {
          return nil
        }
#if DEBUG
        let firstPointerValue = sb.start.loadUnaligned(as: UInt.self)
        assert(firstPointerValue == 0, "First pointer-width value in section '\(sectionName)' at \(sb.start) was expected to equal 0 (found \(firstPointerValue) instead)")
        let lastPointerValue = ((sb.start + sb.size) - MemoryLayout<UInt>.stride).loadUnaligned(as: UInt.self)
        assert(lastPointerValue == 0, "Last pointer-width value in section '\(sectionName)' at \(sb.start) was expected to equal 0 (found \(lastPointerValue) instead)")
#endif
        sb.start += MemoryLayout<UInt>.stride
        sb.size -= (2 * MemoryLayout<UInt>.stride)

        return sb
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
  let sb = SectionBounds(
    imageAddress: nil,
    start: sectionBegin,
    size: max(0, sectionEnd - sectionBegin)
  )
  return CollectionOfOne(sb)
}
#endif
