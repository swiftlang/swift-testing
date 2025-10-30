//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Testing
private import _TestingInternals

#if SWT_FIXED_161205293
@Test func stringsAsCStringArguments() {
  let abc = "abc"
  let _123 = "123"
  let def = "def"
  let _456 = "456"
  #expect(0 == strcmp(abc, abc))
  #expect(0 != strcmp(abc, _123))
  #expect(swt_pointersNotEqual2(abc, _123))
  #expect(swt_pointersNotEqual3(abc, _123, def))
  #expect(swt_pointersNotEqual4(abc, _123, def, _456))
}

@Test func nilStringToCString() {
  let nilString: String? = nil
  #expect(swt_nullableCString(nilString) == false)
}

@Test func inoutAsPointerPassedToCFunction() {
  let num = CLong.random(in: 0 ..< 100)
  let str = String(describing: num)
  str.withCString { str in
    var endptr: UnsafeMutablePointer<CChar>?
    #expect(num == strtol(str, &endptr, 10))
    #expect(endptr != nil)
    #expect(endptr?.pointee == 0)
  }
}

@Test func utf16PointerConversions() throws {
  _ = try withUnsafeTemporaryAllocation(of: UTF16.CodeUnit.self, capacity: 1) { buffer in
    func f(_ p: UnsafeRawPointer?) -> Bool { true }
    func g(_ p: UnsafeMutableRawPointer?) -> Bool { true }
    func h(_ p: UnsafeMutablePointer<UTF16.CodeUnit>?) -> Bool { true }
    #expect(f(buffer.baseAddress))
    #expect(g(buffer.baseAddress))
    #expect(h(buffer.baseAddress))
    return try #require(String.decodeCString(buffer.baseAddress, as: UTF16.self)?.result)
  }
}

@Test func arrayAsCString() {
  let array: [CChar] = Array("abc123".utf8.map(CChar.init(bitPattern:)))
  #expect(0 == strcmp(array, "abc123"))
}

@Test func arrayAsUTF16Pointer() {
  let array: [UTF16.CodeUnit] = [1, 2, 3]
  func f(_ p: UnsafePointer<UTF16.CodeUnit>?) -> Bool { true }
  #expect(f(array))
}

@Test func arrayAsNonBitwiseCopyablePointer() {
  let array: [String] = ["a", "b", "c"]
  func f(_ p: UnsafePointer<String>?) -> Bool { true }
  #expect(f(array))
}
#endif
