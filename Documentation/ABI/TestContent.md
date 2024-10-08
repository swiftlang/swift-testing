# Runtime-discoverable test content

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

This document describes the format and location of test content that the testing
library emits at compile time and can discover at runtime.

> [!WARNING]
> The content of this document is subject to change pending efforts to define a
> Swift-wide standard mechanism for runtime metadata emission and discovery.
> Treat the information in this document as experimental.

## Basic format

Swift Testing uses the [ELF Note format](https://man7.org/linux/man-pages/man5/elf.5.html)
to store individual records of test content. Records created and discoverable by
the testing library are stored in dedicated platform-specific sections:

| Platform | Binary Format | Section Name |
|-|:-:|-|
| macOS, iOS, watchOS, tvOS, visionOS | Mach-O | `__DATA_CONST,__swift5_tests` |
| Linux, FreeBSD, Android | ELF | `PT_NOTE`[^1] |
| WASI | Statically Linked | `swift5_tests` |
| Windows | PE/COFF | `.sw5test`[^2] |

[^1]: On platforms that use the ELF binary format natively, test content records
      are stored in ELF program headers of type `PT_NOTE`. Take care not to
      remove these program headers (for example, by invoking [`strip(1)`](https://www.man7.org/linux/man-pages/man1/strip.1.html).)
[^2]: On Windows, the Swift compiler [emits](https://github.com/swiftlang/swift/blob/main/stdlib/public/runtime/SwiftRT-COFF.cpp)
      leading and trailing padding into this section, both zeroed and of size
      `sizeof(uintptr_t)`. Code that walks this section can safely skip over
      this padding.

### Record headers

Regardless of platform, all test content records created and discoverable by the
testing library have the following structure:

```c
struct SWTTestContentHeader {
  int32_t n_namesz;
  int32_t n_descsz;
  int32_t n_type;
  char n_name[n_namesz];
  // ...
};
```

This structure can be represented in Swift as a heterogenous tuple:

```swift
typealias SWTTestContentHeader = (
  n_namesz: Int32,
  n_descsz: Int32,
  n_type: Int32,
  n_name: (CChar, CChar, /* ... */),
  // ...
)
```

The size of `n_name` is dynamic and cannot be statically computed. The testing
library always generates the name `"Swift Testing"` and specifies an `n_namesz`
value of `20` (the string being null-padded to the correct length), but other
content may be present in the same section whose header size differs. For more
information about this structure such as its alignment requirements, see the
documentation for the [ELF format](https://man7.org/linux/man-pages/man5/elf.5.html).

Each record's _kind_ (stored in the `n_type` field) determines how the record
will be interpreted at runtime:

| Type Value | Interpretation |
|-:|-|
| `< 0` | Undefined (**do not use**) |
| `0 ... 99` | Reserved |
| `100` | Test or suite declaration |
| `101` | Exit test |

<!-- When adding cases to this enumeration, be sure to also update the
corresponding enumeration in TestContentGeneration.swift. -->

### Record contents

For all currently-defined record types, the header structure is immediately
followed by the actual content of the record. A test content record currently
contains an `accessor` function to load the corresponding Swift content and a
`flags` field whose value depends on the type of record. The overall structure
of a record therefore looks like:

```c
struct SWTTestContent {
  SWTTestContentHeader header;
  bool (* accessor)(void *outValue, const void *_Null_unspecified hint);
  uint32_t flags;
  uint32_t reserved;
};
```

Or, in Swift as a tuple:

```swift
typealias SWTTestContent = (
  header: SWTTestContentHeader,
  accessor: @convention(c) (_ outValue: UnsafeMutableRawPointer, _ hint: UnsafeRawPointer?) -> Bool,
  flags: UInt32,
  reserved: UInt32
)
```

This structure may grow in the future as needed. Check the `header.n_descsz`
field to determine if there are additional fields present. Do not assume that
the size of this structure will remain fixed over time or that all discovered
test content records are the same size.

> [!WARNING]
> Do not assume that the fields of `SWTTestContent` are well-aligned. Although
> the ELF Note format is designed to ensure 32-bit alignment, it does _not_
> ensure 64-bit alignment on 64-bit systems. If your code (or the system it will
> run on) is sensitive to the alignment of the fields in this structure, use
> [unaligned loads](https://developer.apple.com/documentation/swift/unsaferawpointer/loadunaligned(frombyteoffset:as:)-5wi7f)
> to read test content records.

#### The accessor field

The function `accessor` is a C function. When called, it initializes the memory
at its argument `outValue` to an instance of some Swift type and returns `true`,
or returns `false` if it could not generate the relevant content. On successful
return, the caller is responsible for deinitializing the memory at `outValue`
when done with it.

The concrete Swift type of the value written to `outValue` depends on the type
of record:

| Type Value | Return Type |
|-:|-|
| `..< 0` | Undefined (**do not use**) |
| `0 ... 99` | Reserved (**do not use**) |
| `100` | `@Sendable () async -> Test`[^3] |
| `101` | `ExitTest` (consumed by caller) |

[^3]: This signature is not the signature of `accessor`, but of the Swift
      function reference it writes to `outValue`. This level of indirection is
      necessary because loading a test or suite declaration is an asynchronous
      operation, but C functions cannot be `async`.

The second argument to this function, `hint`, is an optional input that can be
passed to help the accessor function determine if its corresponding test content
record matches what the caller is looking for. Its type is also dependent on the
type of record:

| Type Value | Hint Type | Notes |
|-:|-|-|
| `100` | Reserved | Always pass `nil`/`nullptr`. |
| `101` | `UnsafePointer<SourceLocation>` | Pass a pointer to the source location of the exit test. |

If the caller passes `nil` as the `hint` argument, the accessor behaves as if it
matched (that is, no additional filtering is performed.)

#### The flags field

- For test or suite declarations (type `100`), the following flags are defined:

  | Bit | Description |
  |-:|-|
  | `1 << 0` | This record contains a suite declaration |
  | `1 << 1` | This record contains a parameterized test function declaration |

- For exit test declarations (type `101`), no flags are currently defined and
  the field should be set to `0`.

#### The reserved field

This field is reserved for future use. Always set it to `0`.

## Third-party test content

Testing tools may make use of the same storage and discovery mechanisms by
emitting their own test content records into the test record content section.

Third-party test content should use the same value for the `n_name` field
(`"Swift Testing"`). The `n_type` field should be set to a unique value only
used by that tool, or used by that tool in collaboration with other compatible
tools. At runtime, Swift Testing ignores test content records with unrecognized
`n_type` values. To reserve a new unique `n_type` value, open a [GitHub issue](https://github.com/swiftlang/swift-testing/issues/new/choose)
against Swift Testing.

The layout of third-party test content records must be compatible with that of
`SWTTestContentHeader` as specified above. For the actual content of a test
record, you do not need to use the same on-disk/in-memory layout as is specified
by `SWTTestContent` above, but it is preferred. Third-party tools are ultimately
responsible for ensuring the values they emit into the test content section are
correctly aligned and have sufficient padding; failure to do so may render
downstream test code unusable.

<!--
TODO: elaborate further, give examples
TODO: standardize a mechanism for third parties to produce `Test` instances
      since we don't have a public initializer for the `Test` type.
-->
