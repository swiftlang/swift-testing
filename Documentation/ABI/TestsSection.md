# Tests section layout

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

This document describes the layout of the tests section emitted by the Swift
compiler on platforms that support image sections (namely those that use Mach-O,
ELF, or COFF images.)

## Image format details

| Image format | Relevant platforms | Name | Padding |
|:-:|:-:|---|--:|
| Mach-O | Darwin | `"__DATA_CONST,__swift5_tests"`\* | None |
| ELF | Linux | `"swift5_tests"` | None |
| COFF | Windows | `".sw5test"` | `1 * sizeof(uintptr_t)` leading and trailing |
| Wasm | WASI | _TBD_ | _TBD_ |

\* `"__DATA_CONST"` is the segment name and `"__swift5_tests"` is the section
  name.

## Section layout

A test section is comprised of a sequence of thin Swift function references
(i.e. function pointers with Swift calling convention.) There is no extraneous
padding between entries in the section (platform-specific leading and trailing
padding is described in the previous table.) Each referenced function has the
following signature:

```swift
typealias TestSectionEntry = @convention(c) @Sendable (
  _ version: CInt,
  _ reserved: UnsafeRawPointer?,
  _ outKind: UnsafeMutablePointer<CInt>,
  _ outValue: UnsafeMutableRawPointer
) -> Void
```

Callers should currently always pass `0` for the `version`. The `reserved`
argument to these functions is (unsurprisingly) reserved and callers should
always pass `nil`. On return, `outValue` always points to an instance of
`any Sendable`. This instance can be cast to one type or another depending on
the value of `outKind.pointee` on return:

| `outKind.pointee` | Entry type | `type(of: outValue.pointee)` |
|---|---|---|
| `0` | Reserved | `Void` |
| `1` | Test function or suite | `@Sendable () async throws -> [Test]` |
| `2` | Exit test descriptor | `ExitTest` |

When calling these functions, callers must:

- Allocate sufficient memory to hold an instance of `any Sendable`
- Call the function
- Cast `outValue` to a pointer to the appropriate type
- Load the value from `outValue` (as needed)
- Deinitialize `outValue`
- Deallocate `outValue`

For example:

```swift
let buffer = UnsafeMutablePointer<any Sendable>.allocate(capacity: 1)
defer {
  buffer.deallocate()
}

for entry: TestSectionEntry in /* ... */ {
  var kind: CInt = 0
  entry(0, nil, &kind, buffer)
  let value = buffer.move()

  switch kind {
  case 1: // Test function or suite
    if let function = value as? @Sendable () async throws -> [Test] {
      // ...
    }
  case 2: // Exit test descriptor
    if let exitTest = value as? ExitTest {
      // ...
    }
  default:
    // Unrecognized or unsupported. Ignore.
    break
  }
}
```
