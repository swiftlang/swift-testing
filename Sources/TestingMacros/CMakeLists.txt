# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

cmake_minimum_required(VERSION 3.28)

if(POLICY CMP0157)
  cmake_policy(SET CMP0157 NEW)
endif()

project(TestingMacros
  LANGUAGES Swift)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

if(WIN32)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

include(FetchContent)

find_package(SwiftSyntax CONFIG GLOBAL)
if(NOT SwiftSyntax_FOUND)
  set(FETCHCONTENT_BASE_DIR ${CMAKE_BINARY_DIR}/_d)
  # TODO: Update GIT_TAG to the 6.0 release tag once it is available.
  FetchContent_Declare(SwiftSyntax
    GIT_REPOSITORY https://github.com/apple/swift-syntax
    GIT_TAG 27b74edd5de625d0e399869a5af08f1501af8837)
  FetchContent_MakeAvailable(SwiftSyntax)
endif()

include(Settings)
add_executable(TestingMacros
  ConditionMacro.swift
  SuiteDeclarationMacro.swift
  Support/Additions/DeclGroupSyntaxAdditions.swift
  Support/Additions/EditorPlaceholderExprSyntaxAdditions.swift
  Support/Additions/FunctionDeclSyntaxAdditions.swift
  Support/Additions/MacroExpansionContextAdditions.swift
  Support/Additions/TokenSyntaxAdditions.swift
  Support/Additions/TriviaPieceAdditions.swift
  Support/Additions/TypeSyntaxProtocolAdditions.swift
  Support/Additions/VersionTupleSyntaxAdditions.swift
  Support/Additions/WithAttributesSyntaxAdditions.swift
  Support/Argument.swift
  Support/AttributeDiscovery.swift
  Support/AvailabilityGuards.swift
  Support/CommentParsing.swift
  Support/ConditionArgumentParsing.swift
  Support/CRC32.swift
  Support/DiagnosticMessage.swift
  Support/DiagnosticMessage+Diagnosing.swift
  Support/SourceCodeCapturing.swift
  Support/SourceLocationGeneration.swift
  TagMacro.swift
  TestDeclarationMacro.swift
  TestingMacrosMain.swift)
set_target_properties(TestingMacros PROPERTIES
  ENABLE_EXPORTS TRUE)
target_compile_options(TestingMacros PRIVATE -parse-as-library)
target_link_libraries(TestingMacros PRIVATE
  SwiftSyntax::SwiftCompilerPlugin
  SwiftSyntax::SwiftSyntax
  SwiftSyntax::SwiftSyntaxMacroExpansion
  SwiftSyntax::SwiftSyntaxMacros
  SwiftSyntax509
  SwiftSyntax510
  SwiftSyntax600)
