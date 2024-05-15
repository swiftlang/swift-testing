# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

# Settings which define commonly-used OS availability macros.
#
# These leverage a pseudo-experimental feature in the Swift compiler for
# setting availability definitions, which was added in
# [apple/swift#65218](https://github.com/apple/swift/pull/65218).
add_compile_options(
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=_mangledTypeNameAPI:macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0\">"
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=_backtraceAsyncAPI:macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0\">"
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=_clockAPI:macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0\">"
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=_regexAPI:macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0\">"
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=_swiftVersionAPI:macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0\">"
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=_distantFuture:macOS 99.0, iOS 99.0, watchOS 99.0, tvOS 99.0\">")
