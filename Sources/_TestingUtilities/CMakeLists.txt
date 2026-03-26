# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for Swift project authors

include(ModuleABIName)
add_library(_TestingUtilities STATIC
  SHA256.swift)

target_compile_options(_TestingUtilities PRIVATE
  -enable-library-evolution
  -emit-module-interface -emit-module-interface-path $<TARGET_PROPERTY:_TestingUtilities,Swift_MODULE_DIRECTORY>/_TestingUtilities.swiftinterface)
set(CMAKE_STATIC_LIBRARY_PREFIX_Swift "lib")

_swift_testing_install_target(_TestingUtilities)

if(NOT BUILD_SHARED_LIBS)
  # When building a static library, install the internal library archive
  # alongside the main library. In shared library builds, the internal library
  # is linked into the main library and does not need to be installed separately.
  install(TARGETS _TestingUtilities
    ARCHIVE DESTINATION "${SwiftTesting_INSTALL_LIBDIR}")
endif()
