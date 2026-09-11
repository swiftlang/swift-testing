// swift-tools-version: 6.2

//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import PackageDescription

let package = Package(
  name: "swift-testing-embedded-demo",
  products: [
    .executable(name: "Application", targets: ["Application"]),
  ],
  dependencies: [
    .package(path: "../.."),
  ],
  targets: [
    .executableTarget(
      name: "Application",
      dependencies: [
        .product(name: "Testing", package: "swift-testing"),
      ]
    ),
  ]
)
