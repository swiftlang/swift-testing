//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import PackagePlugin

@main
struct GitStatus: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
#if os(Windows)
    /// BUG: Build plugins do not currently run on Windows.
    /// swift-package-manager-#6851
    []
#else
    let repoPath = context.package.directory.string
    let generatedSourcePath = context.pluginWorkDirectory.appending("TestingLibraryVersion.swift")
    return [
      .buildCommand(
        displayName: "Getting package repository state",
        executable: try context.tool(named: "GitStatus").path,
        arguments: [repoPath, generatedSourcePath],
        outputFiles: [generatedSourcePath]
      ),
    ]
#endif
  }
}
