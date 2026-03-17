# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024–2026 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for Swift project authors

if(APPLE)
  include(ModuleABIName)
  add_library(_Testing_UniformTypeIdentifiers
    Attachments/AttachableImageFormat+UTType.swift
    Attachments/Attachment+UTType.swift
    ReexportTesting.swift)

  target_link_libraries(_Testing_UniformTypeIdentifiers PUBLIC
    Testing)

  target_compile_options(_Testing_UniformTypeIdentifiers PRIVATE
    -enable-library-evolution
    -emit-module-interface -emit-module-interface-path $<TARGET_PROPERTY:_Testing_UniformTypeIdentifiers,Swift_MODULE_DIRECTORY>/_Testing_UniformTypeIdentifiers.swiftinterface)

  _swift_testing_install_target(_Testing_UniformTypeIdentifiers)
endif()
