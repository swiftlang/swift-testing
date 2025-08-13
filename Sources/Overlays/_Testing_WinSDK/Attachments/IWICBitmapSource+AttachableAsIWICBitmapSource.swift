//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if os(Windows)
import Testing

public import WinSDK

/// A protocol that provides a subclass of `IWICBitmapSource` with its
/// conformance to `_AttachableByAddressAsIWICBitmapSource`.
///
/// - Note: Because COM class inheritance is not visible in Swift, we must
///   manually apply conformances to this protocol to each COM type that
///   inherits from `IWICBitmapSource`.
///
/// This protocol is not part of the public interface of the testing library. It
/// allows us to reuse code across all subclasses of `IWICBitmapSource`.
protocol AttachableByAddressAsSubclassOfIWICBitmapSource: _AttachableByAddressAsIWICBitmapSource {}

extension AttachableByAddressAsSubclassOfIWICBitmapSource {
  public static func _copyAttachableIWICBitmapSource(
    from imageAddress: UnsafeMutablePointer<Self>,
    using factory: UnsafeMutablePointer<IWICImagingFactory>
  ) throws -> UnsafeMutablePointer<IWICBitmapSource> {
    imageAddress.withMemoryRebound(to: IUnknown.self, capacity: 1) { imageAddress in
      _ = imageAddress.pointee.lpVtbl.pointee.AddRef(imageAddress)
    }
    return try imageAddress.cast(to: IWICBitmapSource.self)
  }

  public static func _copyAttachableValue(at imageAddress: UnsafeMutablePointer<Self>) -> UnsafeMutablePointer<Self> {
    imageAddress.withMemoryRebound(to: IUnknown.self, capacity: 1) { imageAddress in
      _ = imageAddress.pointee.lpVtbl.pointee.AddRef(imageAddress)
    }
    return imageAddress
  }

  public static func _deinitializeAttachableValue(at imageAddress: UnsafeMutablePointer<Self>) {
    imageAddress.withMemoryRebound(to: IUnknown.self, capacity: 1) { imageAddress in
      _ = imageAddress.pointee.lpVtbl.pointee.Release(imageAddress)
    }
  }
}

// MARK: -

extension UnsafeMutablePointer where Pointee: AttachableByAddressAsSubclassOfIWICBitmapSource {
  /// Upcast this WIC bitmap to a WIC bitmap source (its parent type).
  ///
  /// - Returns: `self`, cast to the parent type via `QueryInterface()`. The
  ///   caller is responsible for releasing the resulting object.
  ///
  /// - Throws: Any error that occurs while calling `QueryInterface()`. In
  ///   practice, this function is not expected to throw an error as it should
  ///   always be possible to cast a valid instance of `IWICBitmap` to
  ///   `IWICBitmapSource`.
  ///
  /// - Important: This function consumes a reference to `self` even if the cast
  ///   fails.
  consuming func cast(to _: IWICBitmapSource.Type) throws -> UnsafeMutablePointer<IWICBitmapSource> {
    try self.withMemoryRebound(to: IUnknown.self, capacity: 1) { `self` in
      defer {
        _ = self.pointee.lpVtbl.pointee.Release(self)
      }

      return try withUnsafePointer(to: IID_IWICBitmapSource) { IID_IWICBitmapSource in
        var bitmapSource: UnsafeMutableRawPointer?
        let rQuery = self.pointee.lpVtbl.pointee.QueryInterface(self, IID_IWICBitmapSource, &bitmapSource)
        guard rQuery == S_OK, let bitmapSource else {
          throw ImageAttachmentError.queryInterfaceFailed(IWICBitmapSource.self, rQuery)
        }
        return bitmapSource.assumingMemoryBound(to: IWICBitmapSource.self)
      }
    }
  }
}

// MARK: - Conformances

@_spi(Experimental)
extension IWICBitmapSource: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICBitmap: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICBitmapClipper: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICBitmapFlipRotator: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICBitmapFrameDecode: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICBitmapScaler: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICBitmapSourceTransform2: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICColorTransform: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICFormatConverter: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}

@_spi(Experimental)
extension IWICPlanarFormatConverter: _AttachableByAddressAsIWICBitmapSource, AttachableByAddressAsSubclassOfIWICBitmapSource {}
#endif
