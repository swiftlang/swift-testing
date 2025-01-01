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
  static var all: some RandomAccessCollection<SectionBounds> {
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
      let sectionBounds = context!.assumingMemoryBound(to: [SectionBounds].self)

      for i in 0 ..< dlpi_phnum {
        let phdr = dlpi_phdr + Int(i)
        guard phdr.pointee.p_type == PT_NOTE else {
          continue
        }

        let sb = SectionBounds(
          imageAddress: dlpi_addr,
          start: dlpi_addr + Int(bitPattern: UInt(phdr.pointee.p_vaddr)),
          size: Int(phdr.pointee.p_memsz)
        )
        sectionBounds.pointee.append(sb)
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
  // Get the DOS header (to which the HMODULE directly points, conveniently!)
  // and check it's sufficiently valid for us to walk.
  hModule.withMemoryRebound(to: IMAGE_DOS_HEADER.self, capacity: 1) { dosHeader -> SectionBounds? in
    guard dosHeader.pointee.e_magic == IMAGE_DOS_SIGNATURE,
          let e_lfanew = Int(exactly: dosHeader.pointee.e_lfanew), e_lfanew > 0 else {
      return nil
    }

    // Check the NT header. Since we don't use the optional header, skip it.
    let ntHeader = (UnsafeRawPointer(dosHeader) + e_lfanew).assumingMemoryBound(to: IMAGE_NT_HEADERS.self)
    guard ntHeader.pointee.Signature == IMAGE_NT_SIGNATURE else {
      return nil
    }

    let sections = UnsafeBufferPointer(
      start: swt_IMAGE_FIRST_SECTION(ntHeader),
      count: Int(clamping: max(0, ntHeader.pointee.FileHeader.NumberOfSections))
    )
    for section in sections {
      guard let virtualAddress = Int(exactly: section.VirtualAddress), virtualAddress > 0 else {
        continue
      }

      let start = UnsafeRawPointer(dosHeader) + virtualAddress
      let size = Int(clamping: min(max(0, section.Misc.VirtualSize), max(0, section.SizeOfRawData)))

      // Skip over the leading and trailing zeroed uintptr_t values. These
      // values are always emitted by SwiftRT-COFF.cpp into all Swift images.
      if size > 2 * MemoryLayout<UInt>.stride {
        // FIXME: Handle longer names ("/%u") from string table
        let nameMatched = withUnsafeBytes(of: section.Name) { thisSectionName in
          0 == strncmp(sectionName, thisSectionName.baseAddress!, Int(IMAGE_SIZEOF_SHORT_NAME))
        }
        guard nameMatched else {
          continue
        }

#if DEBUG
        let firstPointerValue = start.loadUnaligned(as: UInt.self)
        assert(firstPointerValue == 0, "First pointer-width value in section '\(sectionName)' was expected to equal 0 (found \(firstPointerValue) instead)")
        let lastPointerValue = ((start + size) - MemoryLayout<UInt>.stride).loadUnaligned(as: UInt.self)
        assert(lastPointerValue == 0, "Last pointer-width value in section '\(sectionName)' was expected to equal 0 (found \(lastPointerValue) instead)")
#endif
        return SectionBounds(
          imageAddress: hModule,
          start: start + MemoryLayout<UInt>.stride,
          size: size - (2 * MemoryLayout<UInt>.stride)
        )
      }
    }

    return nil
  }
}

/// The Windows-specific implementation of ``SectionBounds/all``.
///
/// - Returns: An array of structures describing the bounds of all known test
///   content sections in the current process.
private func _testContentSectionBounds() -> [SectionBounds] {
  var result = [SectionBounds]()

  withUnsafeTemporaryAllocation(of: HMODULE?.self, capacity: 1024) { hModules in
    // Find all the modules loaded in the current process. We assume there
    // aren't more than 1024 loaded modules (as does Microsoft sample code.)
    let byteCount = DWORD(hModules.count * MemoryLayout<HMODULE?>.stride)
    var byteCountNeeded: DWORD = 0
    guard K32EnumProcessModules(GetCurrentProcess(), hModules.baseAddress!, byteCount, &byteCountNeeded) else {
      return
    }
    let hModuleCount = min(hModules.count, Int(byteCountNeeded) / MemoryLayout<HMODULE?>.stride)

    // Look in all the loaded modules for Swift type metadata sections. Most
    // modules won't have Swift content, so we don't call sectionBounds.reserve().
    let hModulesEnd = hModules.index(hModules.startIndex, offsetBy: hModuleCount)
    for hModule in hModules[..<hModulesEnd] {
      if let hModule, let sb = _findSection(named: ".sw5test", in: hModule) {
        result.append(sb)
      }
    }
  }

  return result
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
    size: sectionEnd - sectionBegin
  )
  return CollectionOfOne(sb)
}
#endif
