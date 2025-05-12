# This source file is part of the Swift.org open source project
#
# Copyright (c) 2025 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

set(print_target_info_invocation "${CMAKE_Swift_COMPILER}" -print-target-info)
if(CMAKE_Swift_COMPILER_TARGET)
  list(APPEND print_target_info_invocation -target ${CMAKE_Swift_COMPILER_TARGET})
endif()
execute_process(COMMAND ${print_target_info_invocation} OUTPUT_VARIABLE target_info_json)
message(CONFIGURE_LOG "Swift Target Info: ${print_target_info_invocation}\n"
"${target_info_json}")

if(NOT SwiftTesting_MODULE_TRIPLE)
  string(JSON module_triple GET "${target_info_json}" "target" "moduleTriple")
  set(SwiftTesting_MODULE_TRIPLE "${module_triple}" CACHE STRING "Triple used for installed swift{doc,module,interface} files")
  mark_as_advanced(SwiftTesting_MODULE_TRIPLE)

  message(CONFIGURE_LOG "Swift Module Triple: ${module_triple}")
endif()

if(NOT SwiftTesting_PLATFORM_SUBDIR)
  string(JSON platform GET "${target_info_json}" "target" "platform")
  if(NOT platform)
    if(NOT SWIFT_SYSTEM_NAME)
      if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
        set(platform macosx)
      else()
        set(platform $<LOWER_CASE:${CMAKE_SYSTEM_NAME}>)
      endif()
    endif()
  endif()
  set(SwiftTesting_PLATFORM_SUBDIR "${platform}" CACHE STRING "Platform name used for installed swift{doc,module,interface} files")
  mark_as_advanced(SwiftTesting_PLATFORM_SUBDIR)

  message(CONFIGURE_LOG "Swift Platform: ${platform}")
endif()

if(NOT SwiftTesting_ARCH_SUBDIR)
  string(JSON arch GET "${target_info_json}" "target" "arch")
  set(SwiftTesting_ARCH_SUBDIR "${arch}" CACHE STRING "Architecture used for setting the architecture subdirectory")
  mark_as_advanced(SwiftTesting_ARCH_SUBDIR)

  message(CONFIGURE_LOG "Swift Architecture: ${arch}")
endif()
