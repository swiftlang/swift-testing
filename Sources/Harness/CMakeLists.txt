# This source file is part of the Swift.org open source project
#
# Copyright (c) 2026 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for Swift project authors

if(NOT (CMAKE_SYSTEM_NAME IN_LIST SWT_NO_HARNESS_LIST))
  include(ModuleABIName)

  find_package(ArgumentParser CONFIG REQUIRED)

  add_executable(swift-testing-harness
    Harness.swift)
  target_link_libraries(swift-test PRIVATE
    ArgumentParser
    Testing)

  install(TARGETS swift-testing-harness
    RUNTIME DESTINATION "libexec/swift/pm")
endif()
