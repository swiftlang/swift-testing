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
@_spi(Experimental) @_spi(ForToolsIntegrationOnly)
extension Backtrace {
  /// An enumeration describing the symbolication mode to use when handling
  /// events containing backtraces.
  public enum SymbolicationMode: Sendable {
    /// The backtrace should be symbolicated, but no demangling should be
    /// performed.
    case mangled

    /// The backtrace should be symbolicated and Swift symbols should be
    /// demangled if possible.
    ///
    /// "Foreign" symbol names such as those produced by C++ are not demangled.
    case demangled
  }

  /// A type representing an instance of ``Backtrace/Address`` that has been
  /// symbolicated by a call to ``Backtrace/symbolicate(_:)``.
  public struct SymbolicatedAddress: Sendable {
    /// The (unsymbolicated) address from the backtrace.
    public var address: Address

    /// The offset of ``address`` from the start of the corresponding function,
    /// if available.
    ///
    /// If ``address`` could not be resolved to a symbol, the value of this
    /// property is `nil`.
    public var offset: UInt64?

    /// The name of the symbol at ``address``, if available.
    ///
    /// If ``address`` could not be resolved to a symbol, the value of this
    /// property is `nil`.
    public var symbolName: String?
  }

  /// Symbolicate the addresses in this backtrace.
  ///
  /// - Parameters:
  ///   - mode: How to symbolicate the addresses in the backtrace.
  ///
  /// - Returns: An array of strings representing the names of symbols in
  ///   `addresses`.
  ///
  /// If an address in `addresses` cannot be symbolicated, the corresponding
  /// instance of ``SymbolicatedAddress`` in the resulting array has a `nil`
  /// value for its ``Backtrace/SymbolicatedAddress/symbolName`` property.
  public func symbolicate(_ mode: SymbolicationMode) -> [SymbolicatedAddress] {
    var result = addresses.map { SymbolicatedAddress(address: $0) }

#if SWT_TARGET_OS_APPLE
    for (i, address) in addresses.enumerated() {
      var info = Dl_info()
      if 0 != dladdr(UnsafePointer(bitPattern: UInt(clamping: address)), &info) {
        let offset = address - Address(clamping: UInt(bitPattern: info.dli_saddr))
        let symbolName = info.dli_sname.flatMap(String.init(validatingCString:))
        result[i] = SymbolicatedAddress(address: address, offset: offset, symbolName: symbolName)
      }
    }
#elseif os(Linux) || os(FreeBSD) || os(Android)
    // Although these platforms have dladdr(), they do not have symbol names
    // from DWARF binaries by default, only from shared libraries. The standard
    // library's backtracing functionality has implemented sufficient ELF/DWARF
    // parsing to be able to symbolicate Linux backtraces.
    // TODO: adopt the standard library's Backtrace on these platforms
#elseif os(Windows)
    _withDbgHelpLibrary { hProcess in
      guard let hProcess else {
        return
      }
      for (i, address) in addresses.enumerated() {
        withUnsafeTemporaryAllocation(of: SYMBOL_INFO_PACKAGEW.self, capacity: 1) { symbolInfo in
          let symbolInfo = symbolInfo.baseAddress!
          symbolInfo.pointee.si.SizeOfStruct = ULONG(MemoryLayout<SYMBOL_INFOW>.stride)
          symbolInfo.pointee.si.MaxNameLen = ULONG(MAX_SYM_NAME)
          var displacement = DWORD64(0)
          if SymFromAddrW(hProcess, DWORD64(clamping: address), &displacement, symbolInfo.pointer(to: \.si)!) {
            let symbolName = String.decodeCString(symbolInfo.pointer(to: \.si.Name)!, as: UTF16.self)?.result
            result[i] = SymbolicatedAddress(address: address, offset: displacement, symbolName: symbolName)
          }
        }
      }
    }
#elseif os(WASI)
    // WASI does not currently support backtracing let alone symbolication.
#else
#warning("Platform-specific implementation missing: backtrace symbolication unavailable")
#endif

    if mode != .mangled {
      result = result.map { symbolicatedAddress in
        var symbolicatedAddress = symbolicatedAddress
        if let demangledName = symbolicatedAddress.symbolName.flatMap(_demangle) {
          symbolicatedAddress.symbolName = demangledName
        }
        return symbolicatedAddress
      }
    }

    return result
  }
}

// MARK: - Codable

extension Backtrace.SymbolicatedAddress: Codable {}

// MARK: - Swift runtime wrappers

/// Demangle a symbol name.
///
/// - Parameters:
///   - mangledSymbolName: The symbol name to demangle.
///
/// - Returns: The demangled form of `mangledSymbolName` according to the
///   Swift standard library or the platform's C++ standard library, or `nil`
///   if the symbol name could not be demangled.
private func _demangle(_ mangledSymbolName: String) -> String? {
  mangledSymbolName.withCString { mangledSymbolName in
    guard let demangledSymbolName = swift_demangle(mangledSymbolName, strlen(mangledSymbolName), nil, nil, 0) else {
      return nil
    }
    defer {
      free(demangledSymbolName)
    }
    return String(validatingCString: demangledSymbolName)
  }
}

#if os(Windows)
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
