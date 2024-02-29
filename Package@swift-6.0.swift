// swift-tools-version: 6.0

//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "swift-testing",

  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .watchOS(.v6),
    .tvOS(.v13),
    .macCatalyst(.v13),
    .visionOS(.v1),
  ],

  products: [
    .library(
      name: "Testing",
      targets: ["Testing"]
    ),
  ],

  dependencies: [
    .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
  ],

  targets: [
    .target(
      name: "Testing",
      dependencies: [
        "TestingInternals",
        "TestingMacros",
      ],
      cxxSettings: .packageSettings,
      swiftSettings: .packageSettings
    ),
    .testTarget(
      name: "TestingTests",
      dependencies: [
        "Testing",
        "_Testing_Foundation",
      ],
      swiftSettings: .packageSettings
    ),

    .macro(
      name: "TestingMacros",
      dependencies: [
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ],
      swiftSettings: .packageSettings
    ),

    // "Support" targets: These contain C family code and are used exclusively
    // by other targets above, not directly included in product libraries.
    .target(
      name: "TestingInternals",
      cxxSettings: .packageSettings
    ),

    // Cross-module overlays (unsupported)
    .target(
      name: "_Testing_Foundation",
      dependencies: [
        "Testing",
      ],
      swiftSettings: .packageSettings
    ),
  ],

  cxxLanguageStandard: .cxx20
)

// BUG: swift-package-manager-#6367
#if !os(Windows)
package.targets.append(contentsOf: [
  .testTarget(
    name: "TestingMacrosTests",
    dependencies: [
      "Testing",
      "TestingMacros",
    ],
    swiftSettings: .packageSettings
  )
])
#endif

extension Array where Element == PackageDescription.SwiftSetting {
  /// Settings intended to be applied to every Swift target in this package.
  /// Analogous to project-level build settings in an Xcode project.
  static var packageSettings: Self {
    [
      .enableExperimentalFeature("StrictConcurrency"),
      .enableUpcomingFeature("ExistentialAny"),

      .enableExperimentalFeature("AccessLevelOnImport"),
      .enableUpcomingFeature("InternalImportsByDefault"),

      .define("SWT_TARGET_OS_APPLE", .when(platforms: [.macOS, .iOS, .macCatalyst, .watchOS, .tvOS, .visionOS])),
    ]
  }
}

extension Array where Element == PackageDescription.CXXSetting {
  /// Settings intended to be applied to every C++ target in this package.
  /// Analogous to project-level build settings in an Xcode project.
  static var packageSettings: Self {
    var result = Self()

    // Capture the testing library's version as a C++ string constant.
    if let git = Context.gitInformation {
      let testingLibraryVersion = if let tag = git.currentTag {
        tag
      } else if git.hasUncommittedChanges {
        "\(git.currentCommit) (modified)"
      } else {
        git.currentCommit
      }
      result.append(.define("_SWT_TESTING_LIBRARY_VERSION", to: #""\#(testingLibraryVersion)""#))
    }

    return result
  }
}
