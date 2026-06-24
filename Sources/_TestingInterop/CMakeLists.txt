# This source file is part of the Swift.org open source project
#
# Copyright (c) 2025 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

include(ModuleABIName)
add_library(_TestingInterop
  FallbackEventHandler.cpp)
target_include_directories(_TestingInterop PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include)
if("${CMAKE_CXX_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC" OR
   "${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
  target_compile_options(_TestingInterop PRIVATE
    /EHa-c)
elseif(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
  target_compile_options(_TestingInterop PRIVATE
    -fno-exceptions -fPIC)
else()
  target_compile_options(_TestingInterop PRIVATE
    -fno-exceptions)
endif()

_swift_testing_install_target(_TestingInterop)

set_property(GLOBAL APPEND PROPERTY SwiftTesting_EXPORTS _TestingInterop)
