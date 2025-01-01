//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

internal import _TestingInternals

#if os(Windows)
/// A bitmask that can be applied to an `HRESULT` or `NTSTATUS` value to get the
/// underlying status code.
///
/// The type of this value is `CInt` rather than `HRESULT` or `NTSTATUS` for
/// consistency between 32-bit and 64-bit Windows.
let STATUS_CODE_MASK = CInt(0xFFFF)

/// The severity and facility bits to mask against a caught signal value before
/// terminating a child process.
///
/// The type of this value is `CInt` rather than `HRESULT` or `NTSTATUS` for
/// consistency between 32-bit and 64-bit Windows. For more information about
/// the `NTSTATUS` type including its bitwise layout, see
/// [Microsoft's documentation](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/87fba13e-bf06-450e-83b1-9241dc81e781).
let STATUS_SIGNAL_CAUGHT_BITS = {
  var result = CInt(0)

  // Set the severity and status bits.
  result |= CInt(STATUS_SEVERITY_ERROR) << 30
  result |= 1 << 29 // "Customer" bit

  // We only have 12 facility bits, but we'll pretend they spell out "s6", short
  // for "Swift 6" of course.
  //
  // We're camping on a specific "facility" code here that we don't think is
  // otherwise in use; if it conflicts with an exit test, we can add an
  // environment variable lookup so callers can override us.
  let FACILITY_SWIFT6 = ((CInt(UInt8(ascii: "s")) << 4) | 6)
  result |= FACILITY_SWIFT6 << 16

#if DEBUG
  assert(
    (result & STATUS_CODE_MASK) == 0,
    "Constructed NTSTATUS mask \(String(result, radix: 16)) encroached on code bits. Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new"
  )
#endif

  return result
}()

// MARK: - HMODULE members

extension HMODULE {
  /// Get the DOS header corresponding to this module.
  ///
  /// - Parameters:
  ///   - body: The function to invoke. A pointer to the module's DOS header is
  ///     passed to this function, or `nil` if it could not be found.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  func withDOSHeader<R>(_ body: (UnsafePointer<IMAGE_DOS_HEADER>?) throws -> R) rethrows -> R {
    // Get the DOS header (to which the HMODULE directly points, conveniently!)
    // and check it's sufficiently valid for us to walk.
    try withMemoryRebound(to: IMAGE_DOS_HEADER.self, capacity: 1) { dosHeader in
      guard dosHeader.pointee.e_magic == IMAGE_DOS_SIGNATURE else {
        return try body(nil)
      }
      return try body(dosHeader)
    }
  }

  /// Get the NT header corresponding to this module.
  ///
  /// - Parameters:
  ///   - body: The function to invoke. A pointer to the module's NT header is
  ///     passed to this function, or `nil` if it could not be found.
  ///
  /// - Returns: Whatever is returned by `body`.
  ///
  /// - Throws: Whatever is thrown by `body`.
  func withNTHeader<R>(_ body: (UnsafePointer<IMAGE_NT_HEADERS>?) throws -> R) rethrows -> R {
    try withDOSHeader { dosHeader in
      guard let dosHeader,
            let e_lfanew = Int(exactly: dosHeader.pointee.e_lfanew), e_lfanew > 0 else {
        return try body(nil)
      }

      let ntHeader = (UnsafeRawPointer(dosHeader) + e_lfanew).assumingMemoryBound(to: IMAGE_NT_HEADERS.self)
      guard ntHeader.pointee.Signature == IMAGE_NT_SIGNATURE else {
        return try body(nil)
      }
      return try body(ntHeader)
    }
  }
}
#endif
