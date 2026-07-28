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

struct library_record {
  using record_json_handler_function = void (*)(
    const void *record_json,
    size_t record_json_byte_count,
    uintptr_t reserved,
    const void *context
  );

  using completion_handler_function = void (*)(
    const void *result_json,
    size_t result_json_byte_count,
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
    void *out_value,
    const void *type_address,
    const void *hint_address,
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
  static bool store(const char *display_name, const char *name, const library_record& record, void *out_value, const void *type_address, const void *hint_address) {
    if (type_address) {
      const void *type = *static_cast<void *const *const>(type_address);
      if (type != &swift_testing_library_type) {
        return false;
      }
    }

    if (hint_address) {
      const char *hint = *static_cast<char *const *const>(hint_address);
#if defined(_WIN32)
      auto strcasecmp = &_stricmp;
#endif
      if (0 != strcasecmp(hint, display_name) && 0 != strcasecmp(hint, name)) {
        return false;
      }
    }

    std::construct_at(static_cast<library_record *>(out_value), record);
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
  static constexpr swift::testing::library_record _swift_testing_library_record = { \
    (DISPLAY_NAME), \
    (NAME), \
    [] (auto configuration_json, auto configuration_json_byte_count, auto reserved, auto context, auto record_json_handler, auto completion_handler) { \
      (ENTRY_POINT)( \
        std::span((std::byte *)(configuration_json), configuration_json_byte_count), \
        [record_json_handler, context] (std::span<std::byte> record_json) { \
record_json_handler(record_json.data(), record_json.size(), 0, context); \
        }, \
        [completion_handler, context] (int success) { \
          std::ostringstream ss; \
          ss << success; \
          auto result_json = ss.str(); \
          completion_handler(result_json.c_str(), result_json.size(), 0, context); \
        } \
      ); \
    }, \
    {} \
  }; \
  _SWIFT_TESTING_SECTION_ATTR static constinit swift::testing::test_content_record _swift_testing_test_content_record = { \
    'main', \
    0, \
    [] (auto out_value, auto type_address, auto hint_address, auto reserved) -> bool { \
      return swift::testing::test_content_record::store((DISPLAY_NAME), (NAME), _swift_testing_library_record, out_value, type_address, hint_address); \
    } \
  }

#define SWIFT_TESTING_BIND_LIBRARY(DISPLAY_NAME, NAME, ENTRY_POINT) \
  SWIFT_TESTING_BIND_LIBRARY_ASYNC((DISPLAY_NAME), (NAME), [] (auto configuration_json, auto record_json_handler, auto completion_handler) { \
    completion_handler((ENTRY_POINT)(configuration_json, record_json_handler)); \
  })

#endif
