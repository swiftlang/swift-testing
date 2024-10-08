//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals

#if !SWT_NO_DYNAMIC_LINKING

/// The platform-specific type of a loaded image handle.
#if SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD) || os(Android)
typealias ImageAddress = UnsafeMutableRawPointer
#elseif os(Windows)
typealias ImageAddress = HMODULE
#else
#warning("Platform-specific implementation missing: Dynamic loading unavailable")
typealias ImageAddress = Never
#endif

/// The value of `RTLD_DEFAULT` on this platform.
///
/// This value is provided because `errno` is a complex macro on some platforms
/// and cannot be imported directly into Swift. As well, `RTLD_DEFAULT` is only
/// defined on Linux when `_GNU_SOURCE` is defined, so it is not sufficient to
/// declare a wrapper function in the internal module's Stubs.h file.
#if SWT_TARGET_OS_APPLE || os(FreeBSD)
private nonisolated(unsafe) let RTLD_DEFAULT = ImageAddress(bitPattern: -2)
#elseif os(Android) && _pointerBitWidth(_32)
private nonisolated(unsafe) let RTLD_DEFAULT = ImageAddress(bitPattern: UInt(0xFFFFFFFF))
#elseif os(Linux) || os(Android)
private nonisolated(unsafe) let RTLD_DEFAULT = ImageAddress(bitPattern: 0)
#endif

/// Use the platform's dynamic loader to get a symbol in the current process
/// at runtime.
///
/// - Parameters:
///   - handle: A platform-specific handle to the image in which to look for
///     `symbolName`. If `nil`, the symbol may be found in any image loaded
///     into the current process.
///   - symbolName: The name of the symbol to find.
///
/// - Returns: A pointer to the specified symbol, or `nil` if it could not be
///   found.
///
/// Callers looking for a symbol declared in a specific image should pass a
/// handle acquired from `dlopen()` as the `handle` argument. On Windows, pass
/// the result of `GetModuleHandleW()` or an equivalent function.
///
/// On Apple platforms and Linux, when `handle` is `nil`, this function is
/// equivalent to `dlsym(RTLD_DEFAULT, symbolName)`.
///
/// On Windows, there is no equivalent of `RTLD_DEFAULT`. It is simulated by
/// calling `EnumProcessModules()` and iterating over the returned handles
/// looking for one containing the given function.
func symbol(in handle: ImageAddress? = nil, named symbolName: String) -> UnsafeRawPointer? {
#if SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD) || os(Android)
  dlsym(handle ?? RTLD_DEFAULT, symbolName).map(UnsafeRawPointer.init)
#elseif os(Windows)
  symbolName.withCString { symbolName in
    // If the caller supplied a module, use it.
    if let handle {
      return GetProcAddress(handle, symbolName).map {
        unsafeBitCast($0, to: UnsafeRawPointer.self)
      }
    }

    return HMODULE.all.lazy
      .compactMap { GetProcAddress($0, symbolName) }
      .map { unsafeBitCast($0, to: UnsafeRawPointer.self) }
      .first
  }
#else
#warning("Platform-specific implementation missing: Dynamic loading unavailable")
  return nil
#endif
}
#endif
