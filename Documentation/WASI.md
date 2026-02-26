# Running tests for WebAssembly

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

<!-- NOTE: The voice of this document is directed at the second person ("you")
because it provides instructions the reader must follow directly. -->

To run tests for WebAssembly, install a Swift SDK for WebAssembly by following
[these instructions](https://www.swift.org/documentation/articles/wasm-getting-started.html).

## Swift Development Snapshots

In Swift development snapshots, running `swift test --swift-sdk <wasm_swift_sdk_id>` is fully
supported. When you have `jq` installed, you can run this to compute Swift SDK ID automatically:

```
swift test --swift-sdk $"(swiftc -print-target-info | from json | get swiftCompilerTag)_wasm"
```

## Swift 6.2

In Swift 6.2 `swift test` doesn't know what WebAssembly environment you'd like to use
to run your tests, building tests and running them are two separate steps. To
build tests for WebAssembly, use the following command:

```sh
swift build --swift-sdk wasm32-unknown-wasi --build-tests
```

After building tests, you can run them using a [WASI](https://wasi.dev/)-compliant
WebAssembly runtime such as [WasmKit](https://github.com/swiftwasm/WasmKit). 
Starting with Swift 6.2, WasmKit is included in Swift toolchains for Linux and macOS
distributed on swift.org. For example, to run tests using
WasmKit, use the following command (replace `{YOURPACKAGE}` with your package's
name):

```sh
wasmkit run .build/debug/{YOURPACKAGE}PackageTests.wasm --testing-library swift-testing
```

Most WebAssembly runtimes forward trailing arguments to the WebAssembly program,
so you can pass command-line options of the testing library. For example, to list
all tests and filter them by name, use the following commands:

```sh
wasmkit run .build/debug/{YOURPACKAGE}PackageTests.wasm list --testing-library swift-testing
wasmkit run .build/debug/{YOURPACKAGE}PackageTests.wasm --testing-library swift-testing --filter "FoodTruckTests.foodTruckExists"
```
