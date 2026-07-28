//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWIFT_TESTING_LIBRARY_BINDING_CXX_H)
#define SWIFT_TESTING_LIBRARY_BINDING_CXX_H

#include <array>
#include <cassert>
#include <cinttypes>
#include <cstddef>
#include <iostream>
#include <new>
#include <span>
#include <sstream>
#include <string>

namespace swift::testing {
// MARK: - Library record

struct library {
  using record_json_handler_function = void (*)(
    const void *recordJSON,
    size_t recordJSONByteCount,
    uintptr_t reserved,
    const void *context
  );

  using completion_handler_function = void (*)(
    const void *resultJSON,
    size_t resultJSONByteCount,
    uintptr_t reserved,
    const void *context
  );

  using entry_point_function = void (*)(
    const void *configuration_json,
    size_t configuration_json_byte_count,
    uintptr_t reserved,
    const void *context,
    record_json_handler_function record_json_handler,
    completion_handler_function completion_handler
  );

  const char *display_name;
  const char *name;
  entry_point_function entry_point;
  std::array<uintptr_t, 5> reserved;
};

// MARK: - Test content record

struct test_content_record {
  using accessor_function = bool (*)(
    void *outValue,
    const void *typeAddress,
    const void *hintAddress,
    uintptr_t reserved
  );

  uint32_t kind;
  uint32_t reserved1;
  accessor_function accessor;
  uintptr_t context;
  uintptr_t reserved2;

private:
  // FIXME: dynamically look up the type using the Swift runtime so linkage isn't required
  static const char swift_testing_library_type[] __asm__("_$s7Testing7LibraryVN");

public:
  static bool store(const char *displayName, const char *name, const library& record, void *outValue, const void *typeAddress, const void *hintAddress) {
    const void *type = *static_cast<void *const *const>(typeAddress);
    if (type != &swift_testing_library_type) {
      return false;
    }

    if (hintAddress) {
      const char *hint = *static_cast<char *const *const>(hintAddress);
#if defined(_WIN32)
      auto strcasecmp = &_stricmp;
#endif
      if (0 != strcasecmp(hint, displayName) && 0 != strcasecmp(hint, name)) {
        return false;
      }
    }

    ::new (static_cast<library *>(outValue)) library(record);
    return true;
  }
};
}

// MARK: - Macro wrappers

#if defined(__MACH__)
#define _SWIFT_TESTING_SECTION_ATTR __attribute__((__used__, __section__("__DATA_CONST,__swift5_tests")))
#elif defined(__ELF__) || defined(__wasi__)
#define _SWIFT_TESTING_SECTION_ATTR __attribute__((__used__, __section__("swift5_tests")))
#elif defined(_WIN32)
#define _SWIFT_TESTING_SECTION_ATTR __attribute__((__used__, __section__(".sw5test$B")))
#else
#define _SWIFT_TESTING_SECTION_ATTR
#error Unknown executable image format.
#endif

#define SWIFT_TESTING_BIND_LIBRARY_ASYNC(DISPLAY_NAME, NAME, ENTRY_POINT) \
  static constexpr swift::testing::library _swift_testing_library_record = { \
    (DISPLAY_NAME), \
    (NAME), \
    [] (auto configurationJSON, auto configurationJSONByteCount, auto reserved, auto context, auto recordJSONHandler, auto completionHandler) { \
      (ENTRY_POINT)( \
        std::span((std::byte *)(configurationJSON), configurationJSONByteCount), \
        [recordJSONHandler, context] (std::span<std::byte> recordJSON) { \
          recordJSONHandler(recordJSON.data(), recordJSON.size(), 0, context); \
        }, \
        [completionHandler, context] (int success) { \
          std::ostringstream ss; \
          ss << success; \
          auto resultJSON = ss.str(); \
          completionHandler(resultJSON.c_str(), resultJSON.size(), 0, context); \
        } \
      ); \
    }, \
    {} \
  }; \
  _SWIFT_TESTING_SECTION_ATTR static constinit swift::testing::test_content_record _swift_testing_test_content_record = { \
    'main', \
    0, \
    [] (auto outValue, auto typeAddress, auto hintAddress, auto reserved) -> bool { \
      return swift::testing::test_content_record::store((DISPLAY_NAME), (NAME), _swift_testing_library_record, outValue, typeAddress, hintAddress); \
    } \
  }

#define SWIFT_TESTING_BIND_LIBRARY(DISPLAY_NAME, NAME, ENTRY_POINT) \
  SWIFT_TESTING_BIND_LIBRARY_ASYNC((DISPLAY_NAME), (NAME), [] (auto configurationJSON, auto recordJSONHandler, auto completionHandler) { \
    completionHandler((ENTRY_POINT)(configurationJSON, recordJSONHandler)); \
  })

#endif
