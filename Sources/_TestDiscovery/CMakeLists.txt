# This source file is part of the Swift.org open source project
#
# Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

add_library(_TestDiscovery STATIC
  Additions/WinSDKAdditions.swift
  DiscoverableAsTestContent.swift
  SectionBounds.swift
  TestContentRecord.swift)

target_link_libraries(_TestDiscovery PRIVATE
  _TestingInternals)

target_compile_options(_TestDiscovery PRIVATE
  -enable-library-evolution
  -emit-module-interface -emit-module-interface-path $<TARGET_PROPERTY:_TestDiscovery,Swift_MODULE_DIRECTORY>/_TestDiscovery.swiftinterface)
set(CMAKE_STATIC_LIBRARY_PREFIX_Swift "lib")

_swift_testing_install_target(_TestDiscovery)

if(NOT BUILD_SHARED_LIBS)
  # When building a static library, install the internal library archive
  # alongside the main library. In shared library builds, the internal library
  # is linked into the main library and does not need to be installed separately.
  get_swift_testing_install_lib_dir(STATIC_LIBRARY lib_destination_dir)
  install(TARGETS _TestDiscovery
    ARCHIVE DESTINATION ${lib_destination_dir})
endif()
