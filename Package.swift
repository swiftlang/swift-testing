// swift-tools-version: 5.9

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
      swiftSettings: .packageSettings + [
        .enableExperimentalFeature("AccessLevelOnImport"),
        .enableUpcomingFeature("InternalImportsByDefault"),
      ],
      plugins: ["GitStatusPlugin"]
    ),
    .testTarget(
      name: "TestingTests",
      dependencies: [
        "Testing",
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
      swiftSettings: .packageSettings + [
        // The only target which needs the ability to import this macro
        // implementation target's module is its unit test target. Users of the
        // macros this target implements use them via their declarations in the
        // Testing module. This target's module is never distributed to users,
        // but as an additional guard against accidental misuse, this specifies
        // the unit test target as the only allowable client.
        .unsafeFlags(["-Xfrontend", "-allowable-client", "-Xfrontend", "TestingMacrosTests"]),
      ]
    ),

    // "Support" targets: These contain C family code and are used exclusively
    // by other targets above, not directly included in product libraries.
    .target(
      name: "TestingInternals"
    ),

    .plugin(
      name: "GitStatusPlugin",
      capability: .buildTool,
      dependencies: ["GitStatus"]
    ),
    .executableTarget(
      name: "GitStatus",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
      ]
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
      .unsafeFlags([
        "-require-explicit-sendable",

        "-Xfrontend", "-define-availability", "-Xfrontend", "_mangledTypeNameAPI:macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0",
        "-Xfrontend", "-define-availability", "-Xfrontend", "_backtraceAsyncAPI:macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0",
        "-Xfrontend", "-define-availability", "-Xfrontend", "_clockAPI:macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0",
        "-Xfrontend", "-define-availability", "-Xfrontend", "_regexAPI:macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0",
        "-Xfrontend", "-define-availability", "-Xfrontend", "_swiftVersionAPI:macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0",

        "-Xfrontend", "-define-availability", "-Xfrontend", "_distantFuture:macOS 99.0, iOS 99.0, watchOS 99.0, tvOS 99.0",
      ]),
      .enableExperimentalFeature("StrictConcurrency"),
      .enableUpcomingFeature("ExistentialAny"),
      .define("SWT_TARGET_OS_APPLE", .when(platforms: [.macOS, .iOS, .macCatalyst, .watchOS, .tvOS, .visionOS])),
    ]
  }
}
