# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

cmake_minimum_required(VERSION 3.19.6...3.29)

if(POLICY CMP0157)
  cmake_policy(SET CMP0157 NEW)
endif()

project(SwiftTesting
  LANGUAGES CXX Swift)

if(NOT APPLE)
  if(NOT CMAKE_SYSTEM_NAME STREQUAL WASI)
    find_package(dispatch CONFIG)
  endif()
  find_package(Foundation CONFIG)
endif()

include(GNUInstallDirs)

list(APPEND CMAKE_MODULE_PATH
  ${PROJECT_SOURCE_DIR}/cmake/modules
  ${PROJECT_SOURCE_DIR}/cmake/modules/shared)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(CMAKE_INSTALL_RPATH $<IF:$<PLATFORM_ID:Darwin>,"@loader_path/..","$ORIGIN">)
set(CMAKE_INSTALL_REMOVE_ENVIRONMENT_RPATH YES)

set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_Swift_LANGUAGE_VERSION 6)
set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

include(PlatformInfo)
include(SwiftModuleInstallation)

option(SwiftTesting_INSTALL_NESTED_SUBDIR "Install libraries under a platform and architecture subdirectory" NO)
set(SwiftTesting_INSTALL_LIBDIR "${CMAKE_INSTALL_LIBDIR}/swift$<$<NOT:$<BOOL:${BUILD_SHARED_LIBS}>>:_static>/${SwiftTesting_PLATFORM_SUBDIR}$<$<AND:$<PLATFORM_ID:Darwin>,$<NOT:$<BOOL:${SwiftTesting_INSTALL_NESTED_SUBDIR}>>>:/testing>$<$<BOOL:${SwiftTesting_INSTALL_NESTED_SUBDIR}>:/${SwiftTesting_ARCH_SUBDIR}>")
set(SwiftTesting_INSTALL_SWIFTMODULEDIR "${CMAKE_INSTALL_LIBDIR}/swift$<$<NOT:$<BOOL:${BUILD_SHARED_LIBS}>>:_static>/${SwiftTesting_PLATFORM_SUBDIR}$<$<AND:$<PLATFORM_ID:Darwin>,$<NOT:$<BOOL:${SwiftTesting_INSTALL_NESTED_SUBDIR}>>>:/testing>$<$<BOOL:${SwiftTesting_INSTALL_NESTED_SUBDIR}>:/${SwiftTesting_PLATFORM_SUBDIR}>")

add_compile_options($<$<COMPILE_LANGUAGE:Swift>:-no-toolchain-stdlib-rpath>)

add_subdirectory(Sources)
