# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

add_library(_TestDiscovery
  DiscoverableAsTestContent.swift
  SectionBounds.swift
  TestContentRecord.swift)

target_link_libraries(_TestDiscovery PRIVATE
  _TestingInternals)

target_compile_options(_TestDiscovery PRIVATE
  -enable-library-evolution)

_swift_testing_install_target(_TestDiscovery)
