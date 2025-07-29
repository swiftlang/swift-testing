//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024–2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if os(Windows)
@_spi(Experimental) import Testing

public import WinSDK
private import _Gdiplus

extension AttachableImageFormat {
  /// The set of `ImageCodecInfo` instances known to GDI+.
  /// 
  /// If the testing library was unable to determine the set of image formats,
  /// the value of this property is `nil`.
  private static nonisolated(unsafe) let _allImageCodecInfo: UnsafeBufferPointer<Gdiplus.ImageCodecInfo>? = {
    try? withGDIPlus {
      // Find out the size of the buffer needed.
      var encoderCount = UINT(0)
      var byteCount = UINT(0)
      let rGetSize = Gdiplus.GetImageEncodersSize(&encoderCount, &byteCount)
      guard rGetSize == Gdiplus.Ok else {
        return nil
      }

      // Allocate a buffer of sufficient byte size, then bind the leading bytes
      // to ImageCodecInfo. This leaves some number of trailing bytes unbound to
      // any Swift type.
      let result = UnsafeMutableRawBufferPointer.allocate(
        byteCount: Int(byteCount),
        alignment: MemoryLayout<Gdiplus.ImageCodecInfo>.alignment
      )
      let encoderBuffer = result
        .prefix(MemoryLayout<Gdiplus.ImageCodecInfo>.stride * Int(encoderCount))
        .bindMemory(to: Gdiplus.ImageCodecInfo.self)

      // Read the encoders list.
      let rGetEncoders = Gdiplus.GetImageEncoders(encoderCount, byteCount, encoderBuffer.baseAddress!)
      guard rGetEncoders == Gdiplus.Ok else {
        result.deallocate()
        return nil
      }
      return .init(encoderBuffer)
    }
  }()

  /// Get a `CLSID` value corresponding to the image format with the given MIME
  /// type.
  /// 
  /// - Parameters:
  ///   - mimeType: The MIME type of the image format of interest.
  /// 
  /// - Returns: A `CLSID` value suitable for use with GDI+, or `nil` if none
  ///   was found corresponding to `mimeType`.
  private static func _clsid(forMIMEType mimeType: String) -> CLSID? {
    mimeType.withCString(encodedAs: UTF16.self) { mimeType in
      _allImageCodecInfo?.first { 0 == wcscmp($0.MimeType, mimeType) }?.Clsid
    }
  }

  /// The `CLSID` value corresponding to the PNG image format.
  ///
  /// - Note: The named constant [`ImageFormatPNG`](https://learn.microsoft.com/en-us/windows/win32/gdiplus/-gdiplus-constant-image-file-format-constants)
  ///   is not the correct value and will cause `Image::Save()` to fail if
  ///   passed to it.
  private static let _pngCLSID = _clsid(forMIMEType: "image/png")

  /// The `CLSID` value corresponding to the JPEG image format.
  ///
  /// - Note: The named constant [`ImageFormatJPEG`](https://learn.microsoft.com/en-us/windows/win32/gdiplus/-gdiplus-constant-image-file-format-constants)
  ///   is not the correct value and will cause `Image::Save()` to fail if
  ///   passed to it.
  private static let _jpegCLSID = _clsid(forMIMEType: "image/jpeg")

  /// The `CLSID` value corresponding to this image format.
  public var clsid: CLSID? {
    switch kind {
    case .png:
      Self._pngCLSID
    case .jpeg:
      Self._jpegCLSID
    case let .systemValue(clsid):
      clsid as? CLSID
    }
  }

  /// Initialize an instance of this type with the given `CLSID` value` and
  /// encoding quality.
  ///
  /// - Parameters:
  ///   - clsid: The `CLSID` value corresponding to the image format to use when
  ///     encoding images.
  ///   - encodingQuality: The encoding quality to use when encoding images. For
  ///     the lowest supported quality, pass `0.0`. For the highest supported
  ///     quality, pass `1.0`.
  ///
  /// If the target image format does not support variable-quality encoding,
  /// the value of the `encodingQuality` argument is ignored.
  ///
  /// If `clsid` does not represent an image format supported by GDI+, the
  /// result is undefined. For a list of image formats supported by GDI+, see
  /// the [GetImageEncoders()](https://learn.microsoft.com/en-us/windows/win32/api/gdiplusimagecodec/nf-gdiplusimagecodec-getimageencoders)
  /// function.
  public init(_ clsid: CLSID, encodingQuality: Float = 1.0) {
    self.init(kind: .systemValue(clsid), encodingQuality: encodingQuality)
  }
}
#endif
