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

/// A type representing a binary image such as an executable or dynamic library.
///
/// Instances of this type representing images loaded into the current process
/// can be enumerated using ``Image/forEach(_:)``. To get an instance
/// representing the main executable, use ``Image/main``. To get an instance
/// representing the image that contains some address, use
/// ``Image/init(containing:)``.
///
/// The implementation of this type is inherently platform-specific.
#if SWT_TARGET_OS_APPLE || os(Linux) || os(Windows)
#else
@available(*, unavailable, message: "Runtime image discovery is not supported on this platform.")
#endif
public struct Image: ~Copyable {
  /// The underlying C++ structure.
  var rawValue: SMLImage

  /// Initialize an instance of this type wrapping the given C++ structure.
  ///
  /// - Parameters:
  ///   - image: The C++ structure to wrap.
  init(wrapping image: SMLImage) {
    rawValue = image
  }

  /// Initialize an instance of this type with an arbitrary base address.
  ///
  /// - Parameters:
  ///   - unsafeBaseAddress: The base address of the image.
  ///
  /// The caller is responsible for ensuring that `unsafeBaseAddress` is the
  /// address of a valid image loaded into the current process.
  init(unsafeBaseAddress: UnsafeRawPointer) {
    rawValue = withUnsafeTemporaryAllocation(of: SMLImage.self, capacity: 1) { image in
      image[0].base = unsafeBaseAddress
      image[0].name = nil
      return image.baseAddress!.move()
    }
  }

  /// The name of the image, if available.
  ///
  /// The name of an image is implementation-defined, but is commonly equal to
  /// the filename or file system path of the image on disk.
  public var name: String? {
    rawValue.name.flatMap { name in
#if os(Windows)
      return String.decodeCString(name, as: UTF16.self)?.result
#else
      return String(validatingCString: name)
#endif
    }
  }

  /// Call a function to access the base address of the loaded image.
  ///
  /// - Parameters:
  ///   - body: A function to call. A pointer to the start of the image in
  ///     memory is passed to this function.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  public borrowing func withUnsafePointerToBaseAddress<R, E>(_ body: (UnsafeRawPointer) throws(E) -> R) throws(E) -> R {
    return try body(rawValue.base)
  }
}

// MARK: - Sendable

@available(*, unavailable)
extension Image: Sendable {}

// MARK: - Equatable, Hashable

extension Image {
  public static func ==(lhs: borrowing Self, rhs: borrowing Self) -> Bool {
    lhs.rawValue.base == rhs.rawValue.base
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue.base)
  }
}
