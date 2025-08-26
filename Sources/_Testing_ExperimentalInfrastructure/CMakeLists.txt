# This source file is part of the Swift.org open source project
#
# Copyright (c) 2025 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

add_library(_Testing_ExperimentalInfrastructure
  FallbackEventHandler.swift)

target_link_libraries(_Testing_ExperimentalInfrastructure PRIVATE
  _TestingInternals)
if(NOT BUILD_SHARED_LIBS)
  # When building a static library, tell clients to autolink the internal
  # libraries.
  target_compile_options(Testing PRIVATE
    "SHELL:-Xfrontend -public-autolink-library -Xfrontend _TestingInternals")
endif()
target_compile_options(_Testing_ExperimentalInfrastructure PRIVATE
  -enable-library-evolution
  -emit-module-interface -emit-module-interface-path $<TARGET_PROPERTY:_Testing_ExperimentalInfrastructure,Swift_MODULE_DIRECTORY>/_Testing_ExperimentalInfrastructure.swiftinterface)

_swift_testing_install_target(_Testing_ExperimentalInfrastructure)
