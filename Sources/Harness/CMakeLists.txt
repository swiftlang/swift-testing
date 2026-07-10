# This source file is part of the Swift.org open source project
#
# Copyright (c) 2026 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for Swift project authors

if(NOT (CMAKE_SYSTEM_NAME IN_LIST SWT_NO_HARNESS_LIST))
  include(FetchContent)
  include(ModuleABIName)

  find_package(ArgumentParser CONFIG)
  if(NOT ArgumentParser_FOUND)
    message("-- Vending swift-argument-parser")
    FetchContent_Declare(ArgumentParser
      GIT_REPOSITORY https://github.com/apple/swift-argument-parser
      GIT_TAG 1.5.1)
    FetchContent_MakeAvailable(ArgumentParser)
  endif()

  add_executable(swift-testing-harness
    Harness.swift)
  target_link_libraries(swift-testing-harness PRIVATE
    ArgumentParser
    Testing)

  install(TARGETS swift-testing-harness
    RUNTIME DESTINATION "libexec/swift/testing")
endif()
