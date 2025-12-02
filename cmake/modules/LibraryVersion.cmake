# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

# The current version of the Swift Testing release. For release branches,
# remember to remove -dev.
set(SWT_TESTING_LIBRARY_VERSION "6.2.3")

find_package(Git QUIET)
if(Git_FOUND)
  # Get the commit hash corresponding to the current build. Limit length to 15
  # to match `swift --version` output format.
  execute_process(
    COMMAND ${GIT_EXECUTABLE} rev-parse --short=15 --verify HEAD
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET)

  # Check if there are local changes.
  execute_process(
    COMMAND ${GIT_EXECUTABLE} status -s
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_STATUS
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(GIT_STATUS)
    set(GIT_VERSION "${GIT_VERSION} - modified")
  endif()
endif()

# Combine the hard-coded Swift version with available Git information.
if(GIT_VERSION)
set(SWT_TESTING_LIBRARY_VERSION "${SWT_TESTING_LIBRARY_VERSION} (${GIT_VERSION})")
endif()

# All done!
message(STATUS "Swift Testing version: ${SWT_TESTING_LIBRARY_VERSION}")
add_compile_definitions(
  "$<$<COMPILE_LANGUAGE:CXX>:SWT_TESTING_LIBRARY_VERSION=\"${SWT_TESTING_LIBRARY_VERSION}\">")
