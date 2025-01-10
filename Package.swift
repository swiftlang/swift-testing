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
    {
#if os(Windows)
      .library(
        name: "Testing",
        type: .dynamic, // needed so Windows exports ABI entry point symbols
        targets: ["Testing"]
      )
#else
      .library(
        name: "Testing",
        targets: ["Testing"]
      )
#endif
    }()
  ],

  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.0-latest"),
  ],

  targets: [
    .target(
      name: "Testing",
      dependencies: [
        "_TestingInternals",
        "TestingMacros",
      ],
      exclude: ["CMakeLists.txt", "Testing.swiftcrossimport"],
      cSettings: .packageSettings,
      cxxSettings: .packageSettings,
      swiftSettings: .packageSettings,
      linkerSettings: [
        .linkedLibrary("execinfo", .when(platforms: [.custom("freebsd"), .openbsd]))
      ]
    ),
    .testTarget(
      name: "TestingTests",
      dependencies: [
        "Testing",
        "_Testing_CoreGraphics",
        "_Testing_Foundation",
      ],
      cSettings: .packageSettings,
      cxxSettings: .packageSettings,
      swiftSettings: .packageSettings + [
        // For testing test content section discovery only
        .enableExperimentalFeature("SymbolLinkageMarkers"),
      ]
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
      exclude: ["CMakeLists.txt"],
      swiftSettings: .packageSettings + [
        // When building as a package, the macro plugin always builds as an
        // executable rather than a library.
        .define("SWT_NO_LIBRARY_MACRO_PLUGINS"),

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
      name: "_TestingInternals",
      exclude: ["CMakeLists.txt"],
      cSettings: .packageSettings,
      cxxSettings: .packageSettings,
      swiftSettings: .packageSettings
    ),

    // Cross-import overlays (not supported by Swift Package Manager)
    .target(
      name: "_Testing_CoreGraphics",
      dependencies: [
        "Testing",
      ],
      path: "Sources/Overlays/_Testing_CoreGraphics",
      cSettings: .packageSettings,
      cxxSettings: .packageSettings,
      swiftSettings: .packageSettings
    ),
    .target(
      name: "_Testing_Foundation",
      dependencies: [
        "Testing",
      ],
      path: "Sources/Overlays/_Testing_Foundation",
      exclude: ["CMakeLists.txt"],
      cSettings: .packageSettings,
      cxxSettings: .packageSettings,
      swiftSettings: .packageSettings
    ),
  ],

  cxxLanguageStandard: .cxx20
)

// BUG: swift-package-manager-#6367
#if !os(Windows) && !os(FreeBSD) && !os(OpenBSD)
package.targets.append(contentsOf: [
  .testTarget(
    name: "TestingMacrosTests",
    dependencies: [
      "Testing",
      "TestingMacros",
    ],
    cSettings: .packageSettings,
    cxxSettings: .packageSettings,
    swiftSettings: .packageSettings
  )
])
#endif

// MARK: - Settings common among languages

protocol LanguageSetting {
  static func define(_ name: String, _ condition: PackageDescription.BuildSettingCondition?) -> Self
}

protocol CFamilyLanguageSetting: LanguageSetting {
  static func define(_ name: String, to value: String?, _ condition: PackageDescription.BuildSettingCondition?) -> Self
}

extension CFamilyLanguageSetting {
  static func define(_ name: String, _ condition: PackageDescription.BuildSettingCondition?) -> Self {
    .define(name, to: nil, condition)
  }
}

extension PackageDescription.SwiftSetting: LanguageSetting {}
extension PackageDescription.CSetting: CFamilyLanguageSetting {}
extension PackageDescription.CXXSetting: CFamilyLanguageSetting {}

// MARK: - Package-wide settings (to be applied to all targets)

extension Array where Element: LanguageSetting {
  /// Settings applied across the different languages that determine if certain
  /// features of the testing library are enabled or not.
  static var compilerConditionals: Self {
    [
      .define("SWT_NO_EXIT_TESTS", .when(platforms: [.iOS, .watchOS, .tvOS, .visionOS, .wasi, .android])),
      .define("SWT_NO_PROCESS_SPAWNING", .when(platforms: [.iOS, .watchOS, .tvOS, .visionOS, .wasi, .android])),
      .define("SWT_NO_SNAPSHOT_TYPES", .when(platforms: [.linux, .custom("freebsd"), .openbsd, .windows, .wasi])),
      .define("SWT_NO_DYNAMIC_LINKING", nil),
      .define("SWT_NO_PIPES", .when(platforms: [.wasi])),
    ]
  }
}

extension Array where Element == PackageDescription.SwiftSetting {
  /// Settings intended to be applied to every Swift target in this package.
  /// Analogous to project-level build settings in an Xcode project.
  static var packageSettings: Self {
    [
      .unsafeFlags(["-require-explicit-sendable"]),
      .enableUpcomingFeature("ExistentialAny"),
      .enableExperimentalFeature("SuppressedAssociatedTypes"),

      .enableExperimentalFeature("AccessLevelOnImport"),
      .enableUpcomingFeature("InternalImportsByDefault"),

      .define("SWT_TARGET_OS_APPLE", .when(platforms: [.macOS, .iOS, .macCatalyst, .watchOS, .tvOS, .visionOS])),
    ] + availabilityMacroSettings + compilerConditionals
  }

  /// Settings which define commonly-used OS availability macros.
  ///
  /// These leverage a pseudo-experimental feature in the Swift compiler for
  /// setting availability definitions, which was added in
  /// [swift#65218](https://github.com/swiftlang/swift/pull/65218).
  private static var availabilityMacroSettings: Self {
    [
      .enableExperimentalFeature("AvailabilityMacro=_mangledTypeNameAPI:macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0"),
      .enableExperimentalFeature("AvailabilityMacro=_uttypesAPI:macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0"),
      .enableExperimentalFeature("AvailabilityMacro=_backtraceAsyncAPI:macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0"),
      .enableExperimentalFeature("AvailabilityMacro=_clockAPI:macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0"),
      .enableExperimentalFeature("AvailabilityMacro=_regexAPI:macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0"),
      .enableExperimentalFeature("AvailabilityMacro=_swiftVersionAPI:macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0"),
      .enableExperimentalFeature("AvailabilityMacro=_typedThrowsAPI:macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0"),

      .enableExperimentalFeature("AvailabilityMacro=_distantFuture:macOS 99.0, iOS 99.0, watchOS 99.0, tvOS 99.0, visionOS 99.0"),
    ]
  }
}

/// The testing library's version as determined by the git repository state.
let testingLibraryVersion: String? = if let git = Context.gitInformation {
  if let tag = git.currentTag {
    tag
  } else if git.hasUncommittedChanges {
    "\(git.currentCommit) (modified)"
  } else {
    git.currentCommit
  }
} else {
  nil
}

extension Array where Element: CFamilyLanguageSetting {
  /// Settings intended to be applied to every C or C++ target in this package.
  /// Analogous to project-level build settings in an Xcode project.
  ///
  /// The Swift compiler uses C settings (not C++ settings) when importing a C
  /// or C++ header.
  static var packageSettings: Self {
    var result = Self()

    result += compilerConditionals

    if let testingLibraryVersion {
      result.append(.define("SWT_TESTING_LIBRARY_VERSION", to: #""\#(testingLibraryVersion)""#, nil))
    }

    return result
  }
}
