# This source file is part of the Swift.org open source project
#
# Copyright (c) 2026 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for Swift project authors

set(SwiftTesting_EXPORTS_FILE ${CMAKE_CURRENT_BINARY_DIR}/SwiftTestingExports.cmake)

configure_file(SwiftTestingConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/SwiftTestingConfig.cmake)

get_property(SwiftTesting_EXPORTS GLOBAL PROPERTY SwiftTesting_EXPORTS)
export(TARGETS ${SwiftTesting_EXPORTS} FILE ${SwiftTesting_EXPORTS_FILE})
