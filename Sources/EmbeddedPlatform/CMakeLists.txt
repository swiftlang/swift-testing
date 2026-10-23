# This source file is part of the Swift.org open source project
#
# Copyright (c) 2026 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for Swift project authors

set(CMAKE_CXX_SCAN_FOR_MODULES 0)

# Copy the Platform Abstraction Layer annex header to /usr/include/swift.
add_custom_command(
    OUTPUT "${SwiftTesting_INSTALL_INCLUDEDIR}/swift/EmbeddedPlatform+Testing.h"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/include/EmbeddedPlatform+Testing.h"
    COMMAND "${CMAKE_COMMAND}" "-E" "copy" "${CMAKE_CURRENT_SOURCE_DIR}/include/EmbeddedPlatform+Testing.h" "${SwiftTesting_INSTALL_INCLUDEDIR}/swift")
