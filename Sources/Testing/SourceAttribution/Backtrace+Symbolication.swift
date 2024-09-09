//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

/// A type representing a backtrace or stack trace.
@_spi(ForToolsIntegrationOnly)
extension Backtrace {
  /// Demangle a symbol name.
  /// 
  /// - Parameters:
  ///   - mangledSymbolName: The symbol name to demangle.
  /// 
  /// - Returns: The demangled form of `mangledSymbolName` according to the
  ///   Swift standard library or the platform's C++ standard library, or `nil`
  ///   if the symbol name could not be demangled.
  private static func _demangle(_ mangledSymbolName: String) -> String? {
    guard let demangledSymbolName = swt_copyDemangledSymbolName(mangledSymbolName) else {
      return nil
    }
    defer {
      free(demangledSymbolName)
    }
    return String(validatingCString: demangledSymbolName)
  }

  /// Symbolicate a sequence of addresses.
  /// 
  /// - Parameters:
  ///   - addresses: The sequence of addresses. These addresses must have
  ///     originated in the current process.
  ///   - mode: How to symbolicate the addresses in the backtrace.
  /// 
  /// - Returns: An array of strings representing the names of symbols in
  ///   `addresses`.
  /// 
  /// If an address in `addresses` cannot be symbolicated, it is converted to a
  /// string using ``Swift/String/init(describingForTest:)``.
  private static func _symbolicate(addresses: UnsafeBufferPointer<UnsafeRawPointer?>, mode: SymbolicationMode) -> [String] {
    let count = addresses.count
    var symbolNames = [(String, displacement: UInt)?](repeating: nil, count: count)

#if SWT_TARGET_OS_APPLE
    for (i, address) in addresses.enumerated() {
      guard let address else {
        continue
      }
      var info = Dl_info()
      if 0 != dladdr(address, &info) {
        let displacement = UInt(bitPattern: address) - UInt(bitPattern: info.dli_saddr)
        if var symbolName = info.dli_sname.flatMap(String.init(validatingCString:)) {
          if mode != .mangled {
            symbolName = _demangle(symbolName) ?? symbolName
          }
          symbolNames[i] = (symbolName, displacement)
        }
      }
    }
#elseif os(Linux)
    // Although Linux has dladdr(), it does not have symbol names from ELF
    // binaries by default. The standard library's backtracing functionality has
    // implemented sufficient ELF/DWARF parsing to be able to symbolicate Linux
    // backtraces. TODO: adopt the standard library's Backtrace on Linux
    // Note that this means on Linux we don't have demangling capability (since
    // we don't have the mangled symbol names in the first place) so this code
    // does not check the mode argument.
#elseif os(Windows)
    _withDbgHelpLibrary { hProcess in
      guard let hProcess else {
        return
      }
      for (i, address) in addresses.enumerated() {
        guard let address else {
          continue
        }

        withUnsafeTemporaryAllocation(of: SYMBOL_INFO_PACKAGEW.self, capacity: 1) { symbolInfo in
          let symbolInfo = symbolInfo.baseAddress!
          symbolInfo.pointee.si.SizeOfStruct = ULONG(MemoryLayout<SYMBOL_INFOW>.stride)
          symbolInfo.pointee.si.MaxNameLen = ULONG(MAX_SYM_NAME)
          var displacement = DWORD64(0)
          if SymFromAddrW(hProcess, DWORD64(clamping: UInt(bitPattern: address)), &displacement, symbolInfo.pointer(to: \.si)!),
             var symbolName = String.decodeCString(symbolInfo.pointer(to: \.si.Name)!, as: UTF16.self)?.result {
            if mode != .mangled {
              symbolName = _demangle(symbolName) ?? symbolName
            }
            symbolNames[i] = (symbolName, UInt(clamping: displacement))
          }
        }
      }
    }
#elseif os(WASI)
    // WASI does not currently support backtracing let alone symbolication.
#else
#warning("Platform-specific implementation missing: backtrace symbolication unavailable")
#endif

    var result = [String]()
    result.reserveCapacity(count)
    for (i, address) in addresses.enumerated() {
      let formatted = if let (symbolName, displacement) = symbolNames[i] {
        if mode == .preciseDemangled {
          "\(i) \(symbolName) (\(String(describingForTest: address))+\(displacement))"
        } else {
          symbolName
        }
      } else {
        String(describingForTest: address)
      }
      result.append(formatted)
    }
    return result
  }

  /// An enumeration describing the symbolication mode to use when handling
  /// events containing backtraces.
  public enum SymbolicationMode: Sendable {
    /// The backtrace should be symbolicated, but no demangling should be
    /// performed.
    case mangled

    /// The backtrace should be symbolicated and Swift and C++ symbols should be
    /// demangled if possible.
    case demangled

    /// The backtrace should be symbolicated, Swift and C++ symbols should be
    /// demangled if possible, and precise symbol addresses and offsets should
    /// be provided if available.
    case preciseDemangled
  }

  /// Symbolicate the addresses in this backtrace.
  /// 
  /// - Parameters:
  ///   - mode: How to symbolicate the addresses in the backtrace.
  /// 
  /// - Returns: An array of strings representing the names of symbols in
  ///   `addresses`.
  /// 
  /// If an address in `addresses` cannot be symbolicated, it is converted to a
  /// string using ``Swift/String/init(describingForTest:)``.
  public func symbolicate(_ mode: SymbolicationMode) -> [String] {
#if _pointerBitWidth(_64)
      // The width of a pointer equals the width of an `Address`, so we can just
      // bitcast the memory rather than mapping through UInt first.
    addresses.withUnsafeBufferPointer { addresses in
      addresses.withMemoryRebound(to: UnsafeRawPointer?.self) { addresses in
        Self._symbolicate(addresses: addresses, mode: mode)
      }
    }
#else
    let addresses = addresses.map { UnsafeRawPointer(bitPattern: UInt($0)) }
    return addresses.withUnsafeBufferPointer { addresses in
      Self._symbolicate(addresses: addresses, mode: mode)
    }
#endif
  }
}

#if os(Windows)
// MARK: -

/// Configure the environment to allow calling into the Debug Help library.
///
/// - Parameters:
///   - body: A function to invoke. A process handle valid for use with Debug
///     Help functions is passed in, or `nullptr` if the Debug Help library
///     could not be initialized.
///   - context: An arbitrary pointer to pass to `body`.
///
/// On Windows, the Debug Help library (DbgHelp.lib) is not thread-safe. All
/// calls into it from the Swift runtime and stdlib should route through this
/// function.
private func _withDbgHelpLibrary(_ body: (HANDLE?) -> Void) {
  withoutActuallyEscaping(body) { body in
    withUnsafePointer(to: body) { context in
      _swift_win32_withDbgHelpLibrary({ hProcess, context in
        let body = context!.load(as: ((HANDLE?) -> Void).self)
        body(hProcess)
      }, .init(mutating: context))
    }
  }
}
#endif
