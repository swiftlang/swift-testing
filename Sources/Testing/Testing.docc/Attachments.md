# Attachments

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2024–2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Attach values to tests to help diagnose issues and gather feedback.

## Overview

Attach values such as strings and files to tests. Implement the ``Attachable``
protocol to create your own attachable types.

### Attach data or strings

If your test produces encoded data that you want to save as an attachment, you
can call ``Attachment/record(_:named:sourceLocation:)``:

```swift
struct SalesReport { ... }

@Test func `sales report adds up`() async throws {
  let salesReport = await generateSalesReport()
  try salesReport.validate()
  let bytes: [UInt8] = try salesReport.convertToCSV()
  Attachment.record(bytes, named: "sales report.csv")
}
```

You can attach an instance of [`Array<UInt8>`](https://developer.apple.com/documentation/swift/array),
[`ContiguousArray<UInt8>`](https://developer.apple.com/documentation/swift/contiguousarray),
[`ArraySlice<UInt8>`](https://developer.apple.com/documentation/swift/arrayslice),
or [`Data`](https://developer.apple.com/documentation/foundation/data) because
these types automatically conform to ``Attachable``.

You can also attach an instance of [`String`](https://developer.apple.com/documentation/swift/string)
or [`Substring`](https://developer.apple.com/documentation/swift/substring). The
testing library treats attached strings as UTF-8 text
files. If you want to save a string as an attachment using a different encoding,
convert it to [`Data`](https://developer.apple.com/documentation/foundation/data)
using [`data(using:allowLossyConversion:)`](https://developer.apple.com/documentation/swift/stringprotocol/data(using:allowlossyconversion:))
and attach the resulting data instead of the original string.

### Attach encodable values

If you have a value you want to save as an attachment that conforms to either
[`Encodable`](https://developer.apple.com/documentation/swift/encodable) or
[`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding),
you can extend it to add conformance to ``Attachable``. When you import the
[Foundation](https://developer.apple.com/documentation/foundation) module, the
testing library automatically provides a default implementation of
``Attachable`` to types that also conform to [`Encodable`](https://developer.apple.com/documentation/swift/encodable)
or [`NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding):

```swift
import Testing
import Foundation

struct SalesReport { ... }
extension SalesReport: Encodable, Attachable {}

@Test func `sales report adds up`() async throws {
  let salesReport = await generateSalesReport()
  try salesReport.validate()
  Attachment.record(salesReport, named: "sales report.json")
}
```

- Important: The testing library provides these default implementations only if
  your test target imports the [Foundation](https://developer.apple.com/documentation/foundation)
  module.

### Attach images

You can attach instances of the following system-provided image types to a test:

| Platform | Supported Types |
|-|-|
| macOS | [`CGImage`](https://developer.apple.com/documentation/coregraphics/cgimage), [`CIImage`](https://developer.apple.com/documentation/coreimage/ciimage), [`NSImage`](https://developer.apple.com/documentation/appkit/nsimage) |
| iOS, tvOS, and visionOS | [`CGImage`](https://developer.apple.com/documentation/coregraphics/cgimage), [`CIImage`](https://developer.apple.com/documentation/coreimage/ciimage), [`UIImage`](https://developer.apple.com/documentation/uikit/uiimage) |
| watchOS | [`CGImage`](https://developer.apple.com/documentation/coregraphics/cgimage), [`UIImage`](https://developer.apple.com/documentation/uikit/uiimage) |
| Windows | [`HBITMAP`](https://learn.microsoft.com/en-us/windows/win32/gdi/bitmaps), [`HICON`](https://learn.microsoft.com/en-us/windows/win32/menurc/icons), [`IWICBitmapSource`](https://learn.microsoft.com/en-us/windows/win32/api/wincodec/nn-wincodec-iwicbitmapsource) (including its subclasses declared by Windows Imaging Component) |

When you attach an image to a test, you can specify the image format to use in
addition to a preferred name:

```swift
struct SalesReport { ... }

@Test func `sales report adds up`() async throws {
  let salesReport = await generateSalesReport()
  let image = try salesReport.renderTrendsGraph()
  Attachment.record(image, named: "sales report", as: .png)
}
```

If you don't specify an image format when attaching an image to a test, the
testing library selects the format to use based on the preferred name you pass.

### Attach other values

If you have a value that needs a custom encoded representation when you save it
as an attachment, implement ``Attachable/withUnsafeBytes(for:_:)``. The
implementation of this function calls its `body` argument and passes the encoded
representation of `self` or, if a failure occurs, throws an error representing
that failure:

```swift
struct SalesReport { ... }

extension SalesReport: Attachable {
  borrowing func withUnsafeBytes<R>(
    for attachment: borrowing Attachment<Self>,
    _ body: (UnsafeRawBufferPointer) throws -> R
  ) throws -> R {
    let bytes = try salesReport.convertToCSV() // might fail to convert to CSV
    try bytes.withUnsafeBytes { buffer in // rethrows any error from `body`
      try body(buffer)
    }
  }
}
```

If your type conforms to [`Sendable`](https://developer.apple.com/documentation/swift/sendable),
the testing library avoids calling this function until it needs to save the
attachment. If your type does _not_ conform to [`Sendable`](https://developer.apple.com/documentation/swift/sendable),
the testing library calls this function as soon as you record the attachment.

#### Customize attachment behavior

If you can reliably estimate in advance how large the encoded representation
will be, implement ``Attachable/estimatedAttachmentByteCount``. The testing
library uses the value of this property as a hint to optimize memory and disk
usage:

```swift
extension SalesReport: Attachable {
  ...

  var estimatedAttachmentByteCount: Int? {
    return self.entries.count * 123
  }
}
```

You can also implement ``Attachable/preferredName(for:basedOn:)`` if you wish to
customize the name of the attachment when it is saved:

```swift
extension SalesReport: Attachable {
  ...

  borrowing func preferredName(
    for attachment: borrowing Attachment<Self>,
    basedOn suggestedName: String
  ) -> String {
    if suggestedName.lastIndex(of: ".") != nil {
      // The name already contains a path extension, so don't append another.
      return suggestedName
    }

    // Append ".csv" to the name so the resulting file opens as a spreadsheet.
    return "\(suggestedName).csv"
  }
}
```

### Inspect attachments after a test run ends

By default, the testing library saves your attachments as soon as you call
``Attachment/record(_:sourceLocation:)`` or
``Attachment/record(_:named:sourceLocation:)``. You can access saved attachments
after your tests finish running:

- When using Xcode, you can access attachments from the test report.
- When using Visual Studio Code, the testing library saves attachments to
  `.build/attachments` by default. Visual Studio Code reports the paths to
  individual attachments in its Tests Results panel.
- When using Swift Package Manager's `swift test` command, you can pass the
  `--attachments-path` option. The testing library saves attachments to the
  specified directory.

## Topics

### Attaching values to tests

- ``Attachment``
- ``Attachable``
- ``AttachableWrapper``


<!-- TODO: set up DocC content for overlays if possible
### Attaching files to tests

- ``Attachment/init(contentsOf:named:sourceLocation:)``
-->

### Attaching images to tests

- ``AttachableAsImage``
- ``AttachableImageFormat``
- ``Attachment/init(_:named:as:sourceLocation:)``
- ``Attachment/record(_:named:as:sourceLocation:)``
