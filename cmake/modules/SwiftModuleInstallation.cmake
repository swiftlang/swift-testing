# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

# Returns the os name in a variable
#
# Usage:
#   get_swift_host_os(result_var_name)
#
#
# Sets ${result_var_name} with the converted OS name derived from
# CMAKE_SYSTEM_NAME.
function(get_swift_host_os result_var_name)
  set(${result_var_name} ${SWIFT_SYSTEM_NAME} PARENT_SCOPE)
endfunction()

# Returns the path to the Swift Testing library installation directory
#
# Usage:
#   get_swift_testing_install_lib_dir(type result_var_name)
#
# Arguments:
#   type: The type of the library (STATIC_LIBRARY, SHARED_LIBRARY, or EXECUTABLE).
#         Typically, the value of the TYPE target property.
#   result_var_name: The name of the variable to set
function(get_swift_testing_install_lib_dir type result_var_name)
  get_swift_host_os(swift_os)
  if(type STREQUAL STATIC_LIBRARY)
    set(swift swift_static)
  else()
    set(swift swift)
  endif()

  if(APPLE)
    set(${result_var_name} "lib/${swift}/${swift_os}/testing" PARENT_SCOPE)
  else()
    set(${result_var_name} "lib/${swift}/${swift_os}" PARENT_SCOPE)
  endif()
endfunction()

function(_swift_testing_install_target module)
  target_compile_options(Testing PRIVATE "-no-toolchain-stdlib-rpath")

  if(APPLE)
    set_property(TARGET ${module} PROPERTY
      INSTALL_RPATH "@loader_path/..")
  else()
    set_property(TARGET ${module} PROPERTY
      INSTALL_RPATH "$ORIGIN")
  endif()

  get_target_property(type ${module} TYPE)
  get_swift_testing_install_lib_dir(${type} lib_destination_dir)

  install(TARGETS ${module}
    ARCHIVE DESTINATION "${lib_destination_dir}"
    LIBRARY DESTINATION "${lib_destination_dir}"
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
  if(type STREQUAL EXECUTABLE)
    return()
  endif()

  get_target_property(module_name ${module} Swift_MODULE_NAME)
  if(NOT module_name)
    set(module_name ${module})
  endif()

  if(NOT SwiftTesting_MODULE_TRIPLE)
    set(module_triple_command "${CMAKE_Swift_COMPILER}" -print-target-info)
    if(CMAKE_Swift_COMPILER_TARGET)
      list(APPEND module_triple_command -target ${CMAKE_Swift_COMPILER_TARGET})
    endif()
    execute_process(COMMAND ${module_triple_command} OUTPUT_VARIABLE target_info_json)
    string(JSON module_triple GET "${target_info_json}" "target" "moduleTriple")
    set(SwiftTesting_MODULE_TRIPLE "${module_triple}" CACHE STRING "swift module triple used for installed swiftmodule and swiftinterface files")
    mark_as_advanced(SwiftTesting_MODULE_TRIPLE)
  endif()

  set(module_dir "${lib_destination_dir}/${module_name}.swiftmodule")
  install(FILES $<TARGET_PROPERTY:${module},Swift_MODULE_DIRECTORY>/${module_name}.swiftdoc
    DESTINATION "${module_dir}"
    RENAME ${SwiftTesting_MODULE_TRIPLE}.swiftdoc)
  install(FILES $<TARGET_PROPERTY:${module},Swift_MODULE_DIRECTORY>/${module_name}.swiftmodule
    DESTINATION "${module_dir}"
    RENAME ${SwiftTesting_MODULE_TRIPLE}.swiftmodule)
  if(APPLE)
    # Only Darwin has stable ABI. 
    install(FILES $<TARGET_PROPERTY:${module},Swift_MODULE_DIRECTORY>/${module_name}.swiftinterface
      DESTINATION "${module_dir}"
      RENAME ${SwiftTesting_MODULE_TRIPLE}.swiftinterface)
  endif()
endfunction()
