//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation) && !SWT_NO_ABI_ENTRY_POINT
@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
private import _TestingInternals

@Suite("ABI entry point tests")
struct ABIEntryPointTests {
  @Test func v0() async throws {
#if !os(Linux) && !SWT_NO_DYNAMIC_LINKING
    // Get the ABI entry point by dynamically looking it up at runtime.
    //
    // NOTE: The standard Linux linker does not allow exporting symbols from
    // executables, so dlsym() does not let us find this function on that
    // platform when built as an executable rather than a dynamic library.
    let copyABIEntryPoint_v0 = try #require(
      swt_getFunctionWithName(nil, "swt_copyABIEntryPoint_v0").map {
        unsafeBitCast($0, to: (@convention(c) () -> UnsafeMutableRawPointer).self)
      }
    )
#endif
    let abiEntryPoint = copyABIEntryPoint_v0().assumingMemoryBound(to: ABIEntryPoint_v0.self)
    defer {
      abiEntryPoint.deinitialize(count: 1)
      abiEntryPoint.deallocate()
    }

    // Construct arguments and convert them to JSON.
    var arguments = __CommandLineArguments_v0()
    arguments.filter = ["NonExistentTestThatMatchesNothingHopefully"]
    arguments.experimentalEventStreamVersion = 0
    arguments.verbosity = .min
    let argumentsJSON = try JSON.withEncoding(of: arguments) { argumentsJSON in
      let result = UnsafeMutableRawBufferPointer.allocate(byteCount: argumentsJSON.count, alignment: 1)
      _ = memcpy(result.baseAddress!, argumentsJSON.baseAddress!, argumentsJSON.count)
      return result
    }
    defer {
      argumentsJSON.deallocate()
    }

    // Call the entry point function.
    let result = await abiEntryPoint.pointee(.init(argumentsJSON)) { recordJSON in
      let record = try! JSON.decode(ABIv0.Record.self, from: recordJSON)
      _ = record.version
    }

    // Validate expectations.
    #expect(result == EXIT_SUCCESS)
  }
}
#endif
