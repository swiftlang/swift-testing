# This source file is part of the Swift.org open source project
#
# Copyright (c) 2025 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

add_library(_TestingInfrastructure
  FallbackEventHandler.swift)

target_link_libraries(_TestingInfrastructure PRIVATE
  _TestingInternals)
if(NOT BUILD_SHARED_LIBS)
  # When building a static library, tell clients to autolink the internal
  # libraries.
  target_compile_options(Testing PRIVATE
    "SHELL:-Xfrontend -public-autolink-library -Xfrontend _TestingInternals")
endif()
target_compile_options(_TestingInfrastructure PRIVATE
  -enable-library-evolution
  -emit-module-interface -emit-module-interface-path $<TARGET_PROPERTY:_TestingInfrastructure,Swift_MODULE_DIRECTORY>/_TestingInfrastructure.swiftinterface)

_swift_testing_install_target(_TestingInfrastructure)
