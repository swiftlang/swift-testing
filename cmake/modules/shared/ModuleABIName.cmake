##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2025 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0 with Runtime Library Exception
##
## See https://swift.org/LICENSE.txt for license information
## See https://swift.org/CONTRIBUTORS.txt for Swift project authors
##

# This file contains options which should be applied to any Swift target which
# needs to customize its module ABI name. Typically, this is done in order to
# avoid runtime symbol name collisions.

# Pass the appropriate Swift compiler flags to customize the module ABI name.
#
# The specified ABI name can be given a suffix by setting
# `SwiftTesting_MODULE_ABI_NAME_SUFFIX`. By default, no suffix is included but
# builds of the testing library intended for a toolchain can specify a suffix
# so that its symbols will not conflict with either a copy built by a client as
# a Swift package or a precompiled vendor copy.
#
# When determining the base module ABI name to specify, this prefers the
# `Swift_MODULE_NAME` property of the target if it's set, but since that's
# uncommon, it uses its `NAME` property by default.
add_compile_options(
  "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-module-abi-name $<IF:$<BOOL:$<TARGET_PROPERTY:Swift_MODULE_NAME>>,$<TARGET_PROPERTY:Swift_MODULE_NAME>,$<TARGET_PROPERTY:NAME>>${SwiftTesting_MODULE_ABI_NAME_SUFFIX}>")
