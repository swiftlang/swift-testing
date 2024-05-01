# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

# Settings intended to be applied to every Swift target in this package.
# Analogous to project-level build settings in an Xcode project.
add_compile_options(
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -require-explicit-sendable>")
add_compile_options(
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend StrictConcurrency>"
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend AccessLevelOnImport>")
add_compile_options(
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-upcoming-feature -Xfrontend ExistentialAny>"
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-upcoming-feature -Xfrontend InternalImportsByDefault>")

# Settings which define commonly-used OS availability macros.
#
# These leverage a pseudo-experimental feature in the Swift compiler for
# setting availability definitions, which was added in
# [apple/swift#65218](https://github.com/apple/swift/pull/65218).
add_compile_options(
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=_mangledTypeNameAPI:macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0\">"
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=_backtraceAsyncAPI:macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0\">"
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=_clockAPI:macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0\">"
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=_regexAPI:macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0\">"
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=_swiftVersionAPI:macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0\">"
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=_distantFuture:macOS 99.0, iOS 99.0, watchOS 99.0, tvOS 99.0\">")

if(APPLE)
  add_compile_definitions("SWT_TARGET_OS_APPLE")
endif()
if(WASI)
  add_compile_definitions("SWT_NO_FILE_IO")
endif()
if(CMAKE_SYSTEM_NAME IN_LIST "iOS;watchOS;tvOS;visionOS;WASI")
  add_compile_definitions("SWT_NO_EXIT_TESTS")
endif()

find_package(Git QUIET)
if(Git_FOUND)
  execute_process(
    COMMAND ${GIT_EXECUTABLE} describe --tags --exact-match
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_TAG
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET)
  if(GIT_TAG)
    add_compile_definitions(
      "$<$<COMPILE_LANGUAGE:CXX>:_SWT_TESTING_LIBRARY_VERSION=${GIT_TAG}>")
  else()
    execute_process(
      COMMAND ${GIT_EXECUTABLE} rev-parse --verify HEAD
      WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
      OUTPUT_VARIABLE GIT_REVISION
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    execute_process(
      COMMAND ${GIT_EXECUTABLE} status -s
      WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
      OUTPUT_VARIABLE GIT_STATUS
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(GIT_STATUS)
      add_compile_definitions(
        "$<$<COMPILE_LANGUAGE:CXX>:_SWT_TESTING_LIBRARY_VERSION=${GIT_REVISION} (modified)>")
    else()
      add_compile_definitions(
        "$<$<COMPILE_LANGUAGE:CXX>:_SWT_TESTING_LIBRARY_VERSION=${GIT_REVISION}>")
    endif()
  endif()
endif()
