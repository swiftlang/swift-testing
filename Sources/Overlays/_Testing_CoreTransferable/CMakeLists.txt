# This source file is part of the Swift.org open source project
#
# Copyright (c) 2026 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for Swift project authors

if (CMAKE_SYSTEM_NAME STREQUAL "Darwin")
include(ModuleABIName)
  add_library(_Testing_CoreTransferable
    Attachments/_AttachableTransferableWrapper.swift
    Attachments/Attachment+Transferable.swift
    ReexportTesting.swift)

  target_link_libraries(_Testing_CoreTransferable PUBLIC
    Testing
    _Testing_CoreGraphics)

  target_compile_options(_Testing_CoreTransferable PRIVATE
    -enable-library-evolution
    -emit-module-interface -emit-module-interface-path $<TARGET_PROPERTY:_Testing_CoreTransferable,Swift_MODULE_DIRECTORY>/_Testing_CoreTransferable.swiftinterface)

  _swift_testing_install_target(_Testing_CoreTransferable)
endif()
