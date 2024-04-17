//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#include "GetSymbol.h"

#if !defined(SWT_NO_DYNAMIC_LINKING)
#if __has_include(<dlfcn.h>)
#include <dlfcn.h>
#endif

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include <Psapi.h>

#include <vector>

#include "Allocator.h"
#endif

void *swt_getFunctionWithName(void *handle, const char *symbolName) {
#if __has_include(<dlfcn.h>)
  if (!handle) {
    handle = RTLD_DEFAULT;
  }
  return dlsym(handle, symbolName);
#elif defined(_WIN32)
  // If the caller supplied a module, use it.
  if (HMODULE hModule = reinterpret_cast<HMODULE>(handle)) {
    return reinterpret_cast<void*>(GetProcAddress(hModule, symbolName));
  }

  // Find all the modules loaded in the current process.
  std::vector<HMODULE, SWTHeapAllocator<HMODULE>> hModules(1024, nullptr);
  DWORD byteCountNeeded = 0;
  if (!EnumProcessModules(GetCurrentProcess(), &hModules[0], hModules.size() * sizeof(HMODULE), &byteCountNeeded)) {
    return {};
  }
  hModules.resize(byteCountNeeded / sizeof(HMODULE));

  // Enumerate all modules looking for one containing the given symbol.
  for (HMODULE hModule : hModules) {
    if (auto result = GetProcAddress(hModule, symbolName)) {
      return reinterpret_cast<void*>(result);
    }
  }
  return nullptr;
#else
#warning Platform-specific implementation missing: Dynamic loading unavailable
  return nullptr;
#endif
}
#endif
