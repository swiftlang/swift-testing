# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

# Macros must be built for the build machine, not the host.
include(ExternalProject)
ExternalProject_Add(TestingMacros
  CMAKE_CACHE_DEFAULT_ARGS "-DCMAKE_MODULE_PATH:FILEPATH=${CMAKE_MODULE_PATH}"
  PREFIX "tm"
  SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/TestingMacros"
  INSTALL_COMMAND "")
ExternalProject_Get_Property(TestingMacros BINARY_DIR)
if(CMAKE_HOST_WIN32)
  set(TestingMacrosPath "${BINARY_DIR}/TestingMacros.exe#TestingMacros")
else()
  set(TestingMacrosPath "${BINARY_DIR}/TestingMacros#TestingMacros")
endif()

include(Settings)
add_subdirectory(_TestingInternals)
add_subdirectory(Testing)
