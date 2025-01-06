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
  /// A helper type that manages state for ``HMODULE/all``.
  private final class _AllState {
    /// The toolhelp snapshot.
    var snapshot: HANDLE?

    /// The module iterator.
    var me = MODULEENTRY32W()

    deinit {
      if let snapshot {
        CloseHandle(snapshot)
      }
    }
  }

  /// All modules loaded in the current process.
  ///
  /// - Warning: It is possible for one or more modules in this sequence to be
  ///   unloaded while you are iterating over it. To minimize the risk, do not
  ///   discard the sequence until iteration is complete. Modules containing
  ///   Swift code can never be safely unloaded.
  static var all: some Sequence<Self> {
    sequence(state: _AllState()) { state in
      if let snapshot = state.snapshot {
        // We have already iterated over the first module. Return the next one.
        if Module32NextW(snapshot, &state.me) {
          return state.me.hModule
        }
      } else {
        // Create a toolhelp snapshot that lists modules.
        guard let snapshot = CreateToolhelp32Snapshot(DWORD(TH32CS_SNAPMODULE), 0) else {
          return nil
        }
        state.snapshot = snapshot

        // Initialize the iterator for use by the resulting sequence and return
        // the first module.
        state.me.dwSize = DWORD(MemoryLayout.stride(ofValue: state.me))
        if Module32FirstW(snapshot, &state.me) {
          return state.me.hModule
        }
      }

      // Reached the end of the iteration.
      return nil
    }
  }
}
#endif
