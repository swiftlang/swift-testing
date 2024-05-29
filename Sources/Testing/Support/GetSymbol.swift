//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

#if !SWT_NO_DYNAMIC_LINKING

/// The value of `RTLD_DEFAULT` on this platform.
///
/// This value is provided because `errno` is a complex macro on some platforms
/// and cannot be imported directly into Swift. As well, `RTLD_DEFAULT` is only
/// defined on Linux when `_GNU_SOURCE` is defined, so it is not sufficient to
/// declare a wrapper function in the internal module's Stubs.h file.
#if SWT_TARGET_OS_APPLE
private nonisolated(unsafe) let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
#elseif os(Linux)
private nonisolated(unsafe) let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: 0)
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
func symbol(in handle: UnsafeMutableRawPointer? = nil, named symbolName: String) -> UnsafeRawPointer? {
#if SWT_TARGET_OS_APPLE || os(Linux)
  dlsym(handle ?? RTLD_DEFAULT, symbolName).map(UnsafeRawPointer.init)
#elseif os(Windows)
  symbolName.withCString { symbolName in
    // If the caller supplied a module, use it.
    if let handle {
      return GetProcAddress(handle, symbolName)
    }

    // Find all the modules loaded in the current process. We assume there
    // aren't more than 1024 loaded modules (as does Microsoft sample code.)
    return withUnsafeTemporaryAllocation(of: HMODULE.self, capacity: 1024) { hModules in
      let byteCount = DWORD(hModules.count * MemoryLayout<HMODULE>.stride)
      var byteCountNeeded: DWORD = 0
      guard EnumProcessModules(GetCurrentProcess(), hModules.baseAddress!, byteCount, &byteCountNeeded) else {
        return nil
      }

      // Enumerate all modules looking for one containing the given symbol.
      let hModuleCount = min(hModules.count, Int(byteCountNeeded) / MemoryLayout<HMODULE>.stride)
      let hModulesEnd = hModules.index(hModules.startIndex, offsetBy: hModuleCount)
      for hModule in hModules[..<hModulesEnd] {
        if let result = GetProcAddress(hModule, symbolName) {
          return UnsafeRawPointer(result)
        }
      }
      return nil
    }
  }
#else
#warning("Platform-specific implementation missing: Dynamic loading unavailable")
  return nil
#endif
}
#endif
