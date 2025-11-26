//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_INSTR_PROFILING_H)
#define SWT_INSTR_PROFILING_H

#include "Defines.h"
#include "Includes.h"

SWT_ASSUME_NONNULL_BEGIN

/// @defgroup LLVM Profile Runtime Interface
/// @{
///
/// These functions are provided by the LLVM profile runtime when code is
/// compiled with coverage instrumentation (-profile-generate or
/// --enable-code-coverage in Swift).
///
/// Reference: https://github.com/llvm/llvm-project/blob/main/compiler-rt/include/profile/instr_prof_interface.h

/// Reset all profile counters to zero.
///
/// Call this before running a section of code to isolate its coverage from
/// previously executed code.
///
/// @note This function is only available when coverage instrumentation is
/// enabled. Use swt_profilerRuntimeAvailable() to check availability.
SWT_EXTERN void __llvm_profile_reset_counters(void);

/// Write the current profile data to the configured file.
///
/// @returns 0 on success, non-zero on failure.
///
/// @note The output filename is determined by the LLVM_PROFILE_FILE environment
/// variable or can be set with __llvm_profile_set_filename().
SWT_EXTERN int __llvm_profile_write_file(void);

/// Set the filename for subsequent profile writes.
///
/// @param filename The path to write profile data to. This string must remain
/// valid until the next call to this function or until the profile is written.
/// Pass NULL to restore the default filename behavior.
SWT_EXTERN void __llvm_profile_set_filename(const char *_Nullable filename);

/// Write the current profile data and mark it as dumped.
///
/// This function is similar to __llvm_profile_write_file(), but it also marks
/// the profile as "dumped" which prevents the automatic dump that normally
/// occurs at program exit.
///
/// @returns 0 on success, non-zero on failure.
SWT_EXTERN int __llvm_profile_dump(void);

/// @}

/// Check if the LLVM profile runtime is available.
///
/// This function uses dlsym to check for the presence of profile runtime
/// symbols. Returns true if coverage instrumentation is available.
///
/// @note This is a runtime check because the profile symbols are only present
/// when the code was compiled with coverage instrumentation.
static inline bool swt_profilerRuntimeAvailable(void) {
#if __has_include(<dlfcn.h>)
    // Use RTLD_DEFAULT to search all loaded images
#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__)
    void *handle = (void *)(intptr_t)-2; // RTLD_DEFAULT on Apple/BSD
#elif defined(__linux__) || defined(__ANDROID__)
    void *handle = NULL; // RTLD_DEFAULT on Linux
#else
    void *handle = NULL;
#endif
    return dlsym(handle, "__llvm_profile_reset_counters") != NULL;
#else
    return false;
#endif
}

SWT_ASSUME_NONNULL_END

#endif
