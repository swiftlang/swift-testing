# This source file is part of the Swift.org open source project
#
# Copyright (c) 2026 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for Swift project authors

include(ModuleABIName)
add_library(TestingTools
  IssueResponderChain/IssueCapturing.swift
  IssueResponderChain/IssueObservation.swift
  IssueResponderChain/IssueResponder.swift
  )
add_dependencies(TestingTools
  Testing)
target_compile_options(TestingTools PRIVATE
  -enable-library-evolution
  -emit-module-interface -emit-module-interface-path $<TARGET_PROPERTY:TestingTools,Swift_MODULE_DIRECTORY>/TestingTools.swiftinterface)
