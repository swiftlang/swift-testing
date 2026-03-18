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


In Swift 6.3 and later, running `swift test --swift-sdk <wasm_swift_sdk_id>` builds and runs your tests.
Use `jq` to extract the Swift SDK ID automatically to build and test in a single command:

swift test --swift-sdk "$(swiftc -print-target-info | jq -r '.swiftCompilerTag')_wasm"
```

## Build and Test WebAssembly separately

Prior to Swift 6.3, `swift test` doesn't support using the SDK to indicate the WebAssembly environment to use for tests.
In this case, building tests and running them are two separate steps.
To build tests for WebAssembly, use the following command:

```sh
swift build --swift-sdk "$(swiftc -print-target-info | jq -r '.swiftCompilerTag')_wasm" --build-tests
```

After building tests, you can run them using a [WASI](https://wasi.dev/)-compliant
WebAssembly runtime such as [WasmKit](https://github.com/swiftwasm/WasmKit). 
WasmKit is included in the Swift toolchain for Linux and macOS for Swift 6.2 and later.
[Download and install an open-source release toolchain from swift.org](https://swift.org/install) to get a toolchain that includes WasmKit.

To run the rests you built previously using the WasmKit runtime, use the following command, replacing `{YOURPACKAGE}` with the name of your package:

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
