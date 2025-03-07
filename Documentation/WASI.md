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
[these instructions](https://book.swiftwasm.org/getting-started/setup.html).

Because `swift test` doesn't know what WebAssembly environment you'd like to use
to run your tests, building tests and running them are two separate steps. To
build tests for WebAssembly, use the following command:

```sh
swift build --swift-sdk wasm32-unknown-wasi --build-tests
```

After building tests, you can run them using a [WASI](https://wasi.dev/)-compliant
WebAssembly runtime such as [Wasmtime](https://wasmtime.dev/) or
[WasmKit](https://github.com/swiftwasm/WasmKit). For example, to run tests using
Wasmtime, use the following command (replace `{YOURPACKAGE}` with your package's
name):

```sh
wasmtime .build/debug/{YOURPACKAGE}PackageTests.wasm --testing-library swift-testing
```

Most WebAssembly runtimes forward trailing arguments to the WebAssembly program,
so you can pass command-line options of the testing library. For example, to list
all tests and filter them by name, use the following commands:

```sh
wasmtime .build/debug/{YOURPACKAGE}PackageTests.wasm list --testing-library swift-testing
wasmtime .build/debug/{YOURPACKAGE}PackageTests.wasm --testing-library swift-testing --filter "FoodTruckTests.foodTruckExists"
```
