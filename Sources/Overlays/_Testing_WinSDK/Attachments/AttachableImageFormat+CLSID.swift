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
  private static nonisolated(unsafe) let _allImageCodecInfo: UnsafeBufferPointer<Gdiplus.ImageCodecInfo>? = {
    try? withGDIPlus {
      var encoderCount = UINT(0)
      var byteCount = UINT(0)
      let rGetSize = Gdiplus.GetImageEncodersSize(&encoderCount, &byteCount)
      guard rGetSize == Gdiplus.Ok else {
        return nil
      }

      let result = UnsafeMutableRawBufferPointer
        .allocate(byteCount: Int(byteCount), alignment: MemoryLayout<Gdiplus.ImageCodecInfo>.alignment)
        .bindMemory(to: Gdiplus.ImageCodecInfo.self)
      let rGetEncoders = Gdiplus.GetImageEncoders(encoderCount, byteCount, result.baseAddress!)
      guard rGetEncoders == Gdiplus.Ok else {
        result.deallocate()
        return nil
      }

      return .init(result)
    }
  }()

  private static func _clsid(forMIMEType mimeType: String) -> CLSID? {
    mimeType.withCString(encodedAs: UTF16.self) { mimeType in
      _allImageCodecInfo?.first { 0 == wcscmp($0.MimeType, mimeType) }?.Clsid
    }
  }

  var clsid: CLSID? {
    switch kind {
    case .png:
      Self._clsid(forMIMEType: "image/png")
    case .jpeg:
      Self._clsid(forMIMEType: "image/jpeg")
    default:
        fatalError("Unimplemented: custom image formats on Windows")
    }
  }
}
#endif
