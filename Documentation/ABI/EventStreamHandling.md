# Working with the JSON event stream in Swift

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2026 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

This document outlines the `ABI.Record` and `ABI.Encoded*` Swift types and how
to use them.

> [!NOTE]
> These types are marked `@_spi(ForToolsIntegrationOnly)`, so they are only
> available when you build Swift Testing from source. 

## The `ABI` namespace

Swift Testing uses a Swift enumeration type named `ABI` to namespace types,
constants, etc. that are related to Swift Testing's ABI-stable and -semi-stable
interface but which are not exposed to test authors as API. These symbols are
not meant to be used by test authors in typical workflows, but are useful for
_tools_ authors who wish to integrate their tools with Swift Testing.

### The `ABI.Version` and `ABI.VersionNumber` types

Swift Testing uses the `ABI.Version` Swift protocol to define a particular ABI
version, which as of Swift 6.3 is directly tied to a specific Swift toolchain
release. We declare types under the `ABI` namespace that conform to this
protocol. For example, `ABI.v6_3` is a type that conforms to `ABI.Version` and
represents the Swift Testing ABI used in the Swift 6.3 toolchain.

> [!NOTE]
> Unless otherwise stated, Swift toolchain patch releases share an ABI version
> with their previous minor Swift toolchain release. For instance, Swift Testing
> in the Swift 6.3.1 toolchain uses the same ABI as does Swift Testing in the
> Swift 6.3.0 toolchain.

Each type that conforms to `ABI.Version` has a static `versionNumber` property
of type `ABI.VersionNumber`, which is a `Comparable` and `Codable` value that
represents that version. You can use this property to, for example, check if an
`ABI.Version`-conforming type is newer than another:

```swift
let abi: (some ABI.Version).Type 
let isNewerThan6_3 = abi.versionNumber > ABI.v6_3.versionNumber
``` 

Swift Testing also defines `ABI.ExperimentalVersion` to represent experimental
(and **unsupported!**) ABI variants.

## The JSON event stream

The JSON event stream Swift Testing produces at runtime is defined in
[JSON.md](JSON.md). An instance of the Swift type `JSON.Record` represents an
`<output-record>` value as defined in that file. `JSON.Record` itself is generic
over some type conforming to `ABI.Version`; that type provides `JSON.Record`
with the information it needs to correctly encode and decode JSON objects.

> [!NOTE]
> If you are writing your tools using a language other than Swift, you can
> decode the JSON in this stream using your language's JSON decoder and access
> its fields directly. Using languages other than Swift is beyond the scope of
> this document.

### Decoding a JSON event record

To decode an instance of `ABI.Record`, you'll first need to know what ABI
version it was encoded with. We sometimes refer to this version as the JSON
event stream's _schema version_.

To get the appropriate `ABI.Version`-conforming type for a known version number,
you can use `ABI.version(forVersionNumber:)`. If you have a JSON object from the
JSON event stream and do not know what version number to use to decode it, you
can use `ABI.VersionNumber.init(fromRecordJSON:)` to find out.

You can use the following template to decode a JSON object from the JSON event
stream:

```swift
func handleJSONRecord(_ json: Data) throws {
  // Get the ABI version number from the JSON object. Note that this initializer
  // takes an UnsafeRawBufferPointer rather than a Data.
  let versionNumber = try json.withUnsafeBytes { try ABI.VersionNumber(fromRecordJSON: $0) }

  guard let abi = ABI.version(forVersionNumber: versionNumber) else {
    // There is no Swift Testing ABI version associated with the version number
    // provided. Either the JSON object is malformed or the version number is
    // too new for the current version of Swift Testing to support.
    throw ...
  }
  try handleJSONRecord(json, using: abi)
}

func handleJSONRecord<V: ABI.Version>(_ json: Data, using _: V.Type) throws {
  let record = try JSONDecoder().decode(ABI.Record<V>.self, from: json)
  switch record.kind {
  case let .test(test):
    // This record declares the existence of a test.
    try cacheTest(test)
  case let .event(event):
    // This record represents some event that has occurred.
    try handleEvent(event)
  }
}
```

The associated values `test` and `event` in the template above are instances of
the Swift Testing types `ABI.EncodedTest` and `ABI.EncodedEvent`, respectively.
These types represent the JSON-codable subset of information contained in Swift
Testing's `Test` API type and `Event` SPI type. If needed, you can convert them
back to instances of `Test` and `Event` using the `init?(decoding:)` initializer
on either type:

```swift
private let cachedTests = Mutex<[Test.ID: Test]>([:])

func cacheTest<V: ABI.Version>(_ test: ABI.EncodedTest<V>) throws {
  guard let test = Test(decoding: test) else {
    // Swift Testing could not recreate a copy of the original `Test` instance.
    throw ...
  }
  cachedTests.withLock { $0[test.id] = test }
  print("Discovered test '\(test.displayName ?? test.name)' at \(test.sourceLocation)")
}
```

> [!IMPORTANT]
> When you convert an instance of `ABI.EncodedTest` to an instance of `Test` (or
> `ABI.EncodedEvent` to `Event`, etc.), the conversion is lossy. Information
> that was originally available in these values at runtime may not be available
> in the copy you derive from the JSON event stream. In particular, you cannot
> run a Swift Testing test function created in this manner as the body of the
> test is not representable as JSON data.

<!-- TODO: document how to convert runtime Swift values to JSON objects (going the other direction) --> 
