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
let STATUS_CODE_MASK = NTSTATUS(0xFFFF)

/// The severity and facility bits to mask against a caught signal value before
/// terminating a child process.
let STATUS_SIGNAL_CAUGHT_BITS = {
  var result = NTSTATUS(0)

  // Set the severity and status bits.
  result |= STATUS_SEVERITY_ERROR << 30
  result |= 1 << 29 // "Customer" bit

  // We only have 12 facility bits, but we'll pretend they spell out "s6", short
  // for "Swift 6" of course.
  //
  // We're camping on a specific "facility" code here that we don't think is
  // otherwise in use; if it conflicts with an exit test, we can add an
  // environment variable lookup so callers can override us.
  let FACILITY_SWIFT6 = ((NTSTATUS(UInt8(ascii: "s")) << 4) | 6)
  result |= FACILITY_SWIFT6 << 16

#if DEBUG
  assert(
    (result & STATUS_CODE_MASK) == 0,
    "Constructed NTSTATUS mask \(String(result, radix: 16)) encroached on code bits. Please file a bug report at https://github.com/swiftlang/swift-testing/issues/new"
  )
#endif

  return result
}()
#endif
