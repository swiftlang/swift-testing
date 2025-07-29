//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if os(Windows)
@_spi(Experimental) public import Testing

import WinSDK
private import _Gdiplus

@_spi(Experimental)
public struct _AttachableImageWrapper<Image>: Sendable where Image: AttachableAsGDIPlusImage {
  /// The underlying image.
  ///
  /// `CGImage` and `UIImage` are sendable, but `NSImage` is not. `NSImage`
  /// instances can be created from closures that are run at rendering time.
  /// The AppKit cross-import overlay is responsible for ensuring that any
  /// instances of this type it creates hold "safe" `NSImage` instances.
  nonisolated(unsafe) var image: Image

  /// The image format to use when encoding the represented image.
  var imageFormat: AttachableImageFormat?
}

// MARK: -

@available(_uttypesAPI, *)
extension _AttachableImageWrapper: AttachableWrapper {
  public var wrappedValue: Image {
    image
  }

  public func withUnsafeBytes<R>(for attachment: borrowing Attachment<Self>, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    // Create an in-memory stream to write the image data to. Note that Windows
    // documentation recommends SHCreateMemStream() instead, but that function
    // does not provide a mechanism to access the underlying memory directly.
    var stream: UnsafeMutablePointer<IStream>?
    let rCreateStream = CreateStreamOnHGlobal(nil, true, &stream)
    guard S_OK == rCreateStream else {
      throw GDIPlusError.hresult(rCreateStream)
    }
    defer {
      swt_winsdk_IStreamRelease(stream)
    }

    // Get the CLSID of the image encoder corresponding to the specified image
    // format.
    // TODO: infer an image format from the filename like we do on Darwin.
    let imageFormat = self.imageFormat ?? .png
    guard var clsid = imageFormat.clsid else {
      throw GDIPlusError.clsidNotFoundForImageFormat(imageFormat)
    }

    // Save the image into the stream.
    try image.withGDIPlusImage(for: attachment) { image in
      let rSave = swt_winsdk_GdiplusImageSave(image, stream, &clsid, nil)
      guard rSave == Gdiplus.Ok else {
        throw GDIPlusError.status(rSave)
      }
    }

    // Extract the serialized image and pass it back to the caller. We hold the
    // HGLOBAL locked while calling `body`, but nothing else should have a
    // reference to it.
    var global: HGLOBAL?
    let rGetGlobal = GetHGlobalFromStream(stream, &global)
    guard S_OK == rGetGlobal else {
      throw GDIPlusError.hresult(rGetGlobal)
    }
    guard let baseAddress = GlobalLock(global) else {
      throw GDIPlusError.win32Error(GetLastError())
    }
    defer {
      GlobalUnlock(global)
    }
    let byteCount = GlobalSize(global)
    return try body(UnsafeRawBufferPointer(start: baseAddress, count: Int(byteCount)))
  }
}
#endif
