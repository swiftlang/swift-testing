# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

add_library(Testing
  EntryPoints/ABIEntryPoint.swift
  EntryPoints/EntryPoint.swift
  EntryPoints/SwiftPMEntryPoint.swift
  EntryPoints/XCTestScaffold.swift
  Events/Clock.swift
  Events/Event.swift
  Events/Recorder/Event.ConsoleOutputRecorder.swift
  Events/Recorder/Event.HumanReadableOutputRecorder.swift
  Events/Recorder/Event.JUnitXMLRecorder.swift
  Events/Recorder/Event.Symbol.swift
  Events/TimeValue.swift
  ExitTests/ExitCondition.swift
  ExitTests/ExitTest.swift
  ExitTests/WaitFor.swift
  Expectations/Expectation.swift
  Expectations/Expectation+Macro.swift
  Expectations/ExpectationChecking+Macro.swift
  Issues/Confirmation.swift
  Issues/ErrorSnapshot.swift
  Issues/Issue.swift
  Issues/Issue+Recording.swift
  Issues/KnownIssue.swift
  Parameterization/CustomTestArgumentEncodable.swift
  Parameterization/Test.Case.Generator.swift
  Parameterization/Test.Case.ID.swift
  Parameterization/Test.Case.swift
  Parameterization/TypeInfo.swift
  Running/Configuration.swift
  Running/Configuration.TestFilter.swift
  Running/Configuration+EventHandling.swift
  Running/Runner.Plan.swift
  Running/Runner.Plan+Dumping.swift
  Running/Runner.RuntimeState.swift
  Running/Runner.swift
  Running/SkipInfo.swift
  SourceAttribution/Backtrace.swift
  SourceAttribution/CustomTestStringConvertible.swift
  SourceAttribution/Expression.swift
  SourceAttribution/Expression+Macro.swift
  SourceAttribution/SourceContext.swift
  SourceAttribution/SourceLocation.swift
  Support/Additions/ArrayAdditions.swift
  Support/Additions/CollectionDifferenceAdditions.swift
  Support/Additions/CommandLineAdditions.swift
  Support/Additions/NumericAdditions.swift
  Support/Additions/ResultAdditions.swift
  Support/CartesianProduct.swift
  Support/CError.swift
  Support/Environment.swift
  Support/FileHandle.swift
  Support/Graph.swift
  Support/JSON.swift
  Support/Locked.swift
  Support/SystemError.swift
  Support/UncheckedSendable.swift
  Support/Versions.swift
  Test.ID.Selection.swift
  Test.ID.swift
  Test.swift
  Test+Discovery.swift
  Test+Macro.swift
  Traits/Bug.swift
  Traits/Comment.swift
  Traits/Comment+Macro.swift
  Traits/ConditionTrait.swift
  Traits/ConditionTrait+Macro.swift
  Traits/HiddenTrait.swift
  Traits/ParallelizationTrait.swift
  Traits/SPIAwareTrait.swift
  Traits/Tags/Tag.Color.swift
  Traits/Tags/Tag.Color+Loading.swift
  Traits/Tags/Tag.List.swift
  Traits/Tags/Tag.swift
  Traits/Tags/Tag+Macro.swift
  Traits/Tags/Tag+Predefined.swift
  Traits/TimeLimitTrait.swift
  Traits/Trait.swift)
target_link_libraries(Testing PRIVATE
  TestingInternals)
add_dependencies(Testing
  TestingMacros)
target_compile_options(Testing PUBLIC
  -load-plugin-executable "${TestingMacrosPath}")
