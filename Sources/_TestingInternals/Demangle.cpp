//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#include "Demangle.h"

#include <cstdint>
#include <cstdlib>
#include <cstring>

#if defined(__APPLE__) || defined(__linux__)
#include <cxxabi.h>
#elif defined(_WIN32)
#include <DbgHelp.h>
#pragma comment(lib, "DbgHelp.lib")
#endif

SWT_IMPORT_FROM_STDLIB char *swift_demangle(const char *mangledName, size_t mangledNameLength, char *outputBuffer, size_t *outputBufferSize, uint32_t flags);

char *swt_copyDemangledSymbolName(const char *mangledName) {
  if (mangledName[0] == '\0') {
    return nullptr;
  }

  // First, try using Swift's demangler.
  char *result = swift_demangle(mangledName, std::strlen(mangledName), nullptr, nullptr, 0);

  // Try using the platform's C++ demangler instead.
  if (!result) {
#if defined(__APPLE__) || defined(__linux__)
    int status = 0;
    result = __cxxabiv1::__cxa_demangle(mangledName, nullptr, nullptr, &status);
#elif defined(_WIN32)
    // std::type_info::raw_name() has a leading period that interferes with
    // demangling. Strip it off if found.
    if (mangledName[0] == '.') {
      mangledName += 1;
    }

    // MSVC++-style mangled names always start with '?'.
    if (mangledName[0] != '?') {
      return nullptr;
    }

    // Allocate some space for the demangled type name.
    static const constexpr size_t MAX_DEMANGLED_NAME_SIZE = 1024;
    if (auto demangledName = reinterpret_cast<char *>(std::malloc(MAX_DEMANGLED_NAME_SIZE))) {

      // Call into DbgHelp to perform the demangling. These flags should
      // give us the correct demangling of a mangled C++ type name.
      DWORD undecorateFlags = UNDNAME_NAME_ONLY | UNDNAME_NO_ARGUMENTS;
#if !defined(_WIN64)
      undecorateFlags |= UNDNAME_32_BIT_DECODE;
#endif
      if (UnDecorateSymbolName(mangledName, demangledName, MAX_DEMANGLED_NAME_SIZE, undecorateFlags)) {
        result = demangledName;
      } else {
        // Don't leak the allocated buffer if demangling failed.
        std::free(demangledName);
      }
    }
#endif
  }

  return result;
}
