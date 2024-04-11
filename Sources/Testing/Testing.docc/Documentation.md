# ``Testing``

<!-- NOTE: The link above must match the module name, not the package name. -->

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Create and run tests for your Swift packages and Xcode projects.

## Overview

`swift-testing` is a modern, open-source testing library for Swift with powerful
and expressive capabilities. It gives developers more confidence with less code.

### Flexible test organization

Define test functions almost anywhere with a single attribute and group related
tests into hierarchies using Swift's type system.

### Customizable metadata

Dynamically enable or disable tests depending on runtime conditions, categorize
tests using tags, and associate bugs directly with the tests that verify their
fixes or reproduce their problems.

### Scalable execution

Automatically parallelize tests in-process, integrate seamlessly with Swift
concurrency, and parameterize test functions across wide ranges of inputs.

## Topics

### Essentials

- <doc:TemporaryGettingStarted>
- <doc:DefiningTests>
- <doc:OrganizingTests>
- ``Test(_:_:)``
- ``Test``
- ``Suite(_:_:)``

### Parameterized tests

- <doc:ParameterizedTesting>
- ``Test(_:_:arguments:)-8kn7a`` <!-- @attached(peer) macro Test<C>(_ displayName: String? = nil, _ traits: any TestTrait..., arguments collection: C) where C : Collection, C : Sendable, C.Element : Sendable -->
- ``Test(_:_:arguments:_:)``
- ``Test(_:_:arguments:)-3rzok`` <!-- @attached(peer) macro Test<C1, C2>(_ displayName: String? = nil, _ traits: any TestTrait..., arguments zippedCollections: Zip2Sequence<C1, C2>) where C1 : Collection, C1 : Sendable, C2 : Collection, C2 : Sendable, C1.Element : Sendable, C2.Element : Sendable -->
- ``CustomTestArgumentEncodable``
- ``Test/Parameter``
- ``Test/Case``

### Behavior validation

- <doc:Expectations>

### Test customizations

- <doc:Traits>

### Migration

- <doc:MigratingFromXCTest>

### Extended modules

- ``Swift``
