# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

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
