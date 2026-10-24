# This source file is part of the Swift.org open source project
#
# Copyright (c) 2026 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for Swift project authors

set(CMAKE_CXX_SCAN_FOR_MODULES 0)

# Copy the Platform Abstraction Layer annex header to /usr/include/swift.

set(SWIFT_TESTING_PAL_ANNEX_HEADER_NAME "EmbeddedPlatform+Testing.h")
set(SWIFT_TESTING_PAL_ANNEX_HEADER_DST_PATH "${SwiftTesting_INSTALL_INCLUDEDIR}/${SWIFT_TESTING_PAL_ANNEX_HEADER_NAME}")
add_custom_target(EmbeddedPlatformTestingAnnex
  BYPRODUCTS "${SWIFT_TESTING_PAL_ANNEX_HEADER_DST_PATH}"
  COMMAND "${CMAKE_COMMAND}" "-E" "copy" "${CMAKE_CURRENT_SOURCE_DIR}/../_TestingInternals/include/${SWIFT_TESTING_PAL_ANNEX_HEADER_NAME}" "${SwiftTesting_INSTALL_INCLUDEDIR}"
  COMMENT "Copying Embedded Swift platform header (testing annex) to '${SWIFT_TESTING_PAL_ANNEX_HEADER_DST_PATH}'")

message(STATUS "Swift Testing PAL Annex header destination: '${SWIFT_TESTING_PAL_ANNEX_HEADER_DST_PATH}'")

add_dependencies(Testing
  EmbeddedPlatformTestingAnnex)
