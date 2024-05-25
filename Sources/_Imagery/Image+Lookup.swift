//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_BUILDING_WITH_CMAKE
@_implementationOnly import _ImageryInternals
#else
internal import _ImageryInternals
#endif

extension Image {
  /// Initialize an instance of this type representing the loaded image that
  /// contains an arbitrary address in memory.
  ///
  /// - Parameters:
  ///   - address: The address whose containing image is needed.
  ///
  /// If `address` is located within an image loaded into the current process,
  /// the resulting instance represents that image. If `address` is not
  /// contained within any such image, `nil` is returned.
  public init?(containing address: UnsafeRawPointer) {
    let image: SMLImage? = withUnsafeTemporaryAllocation(of: SMLImage.self, capacity: 1) { buffer in
      guard sml_getImageContainingAddress(address, buffer.baseAddress!) else {
        return nil
      }
      return buffer.baseAddress!.move()
    }
    guard let image else {
      return nil
    }
    rawValue = image
  }

  /// The main executable image in the current process.
  public static nonisolated(unsafe) let main: Self = {
    let rawValue = withUnsafeTemporaryAllocation(of: SMLImage.self, capacity: 1) { buffer in
      sml_getMainImage(buffer.baseAddress!)
      return buffer.baseAddress!.move()
    }
    return Self(wrapping: rawValue)
  }()

  /// Enumerate over all images loaded into the current process.
  ///
  /// - Parameters:
  ///   - body: A function to call. For each image loaded into the current
  ///     process, an instance of ``Image`` is passed to this function.
  ///
  /// - Throws: Whatever is thrown by `body`. If an error is thrown, enumeration
  ///   does not continue.
  ///
  /// The order in which images are enumerated is implementation-defined. In
  /// particular, it is not guaranteed that the main image is the first image
  /// enumerated (use ``Image/main`` to get the main image.)
  ///
  /// On some platforms, a global system-owned lock is held while this function
  /// is running. To avoid deadlocks within the system's dynamic loader, it is
  /// recommended that callers minimize the work that is done in `body`.
  ///
  /// On platforms that support dynamically unloading images at runtime, the
  /// values yielded by this function are not guaranteed to remain valid after
  /// it returns.
  public static func forEach<E>(_ body: (borrowing Image) throws(E) -> Void) throws(E) {
    var result: Result<Void, E> = .success(())

    typealias Enumerator = (SMLImage, _ stop: UnsafeMutablePointer<CBool>) -> Void
    let body: Enumerator = { image, stop in
      do {
        try body(Self(wrapping: image))
      } catch {
        result = .failure(error as! E)
        stop.pointee = true
      }
    }

    withoutActuallyEscaping(body) { body in
      withUnsafePointer(to: body) { body in
        sml_enumerateImages(.init(mutating: body)) { context, image, stop in
          let body = context!.load(as: Enumerator.self)
          body(image.pointee, stop)
        }
      }
    }

    return try result.get()
  }
}
