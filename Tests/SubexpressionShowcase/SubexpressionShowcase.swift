//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

import Testing

#warning("TODO: convert this scratchpad into actual unit tests")

func f(_ x: Int, _ y: Int) -> Int {
  x + y
}

func g() throws -> Int {
  22
}

func io(_ x: inout Int) -> Int {
  x += 1
  return x + 1
}

struct T {
  func h(_ i: Int) -> Bool { false }
  static func j(_ d: Double) -> Bool { false }
}

@Test func runSubexpressionShowcase() async {
  await withKnownIssue {
    try await subexpressionShowcase()
  }
}

func subexpressionShowcase() async throws {
  #expect(nil == String?.none)

  let arrayOfArrays: [[Int]] = []
  #expect(arrayOfArrays.filter { $0.first?.trailingZeroBitCount != nil }.count > 0)

  let fff = false
  let ttt = true
  #expect(false || true)

  #expect((fff == ttt) == ttt)

  #expect((Int)(123) == 124)
  #expect((Int, Double)(123, 456.0) == (124, 457.0))
  #expect((123, 456) == (789, 0x12))
  #expect((try g() > 500) && true)

  #expect(!Bool(true))

#if false
  // Unsupported: mutating member functions require inout semantics we can't
  // provide (since we can't see where we might need to insert an `&` sigil).
  // However, we _can_ provide a reasonable diagnostic for it now!
  do {
    struct S {
      mutating func f() -> Bool { false }
    }
    var s = S()
    #expect(s.f())
  }
#endif

  do {
    let n = Int.random(in: 0 ..< 100)
    var m = n
    #expect(io(&m) == n)
  }

  let closure: (Int) -> Void = {
    #expect((($0 + $0 + $0) as Int) == 0x10)
  }
  closure(11)

  struct S: ~Copyable {
    borrowing func h() -> Bool { false }
    consuming func j() -> Bool { false }
  }
  let s = S()
  Testing.__checkCondition({(__ec: Testing.__ExpectationContext<Swift.Bool>) -> Swift.Bool in __ec[__ec[s,0x6].h(),0x0]
  },sourceCode: [0x0:"s.h()",0x6:"s"],comments: [],isRequired: false,sourceLocation: Testing.SourceLocation.__here()).__expected()
  // #expect(s.h())
#if false
  #expect(s.j()) // consuming -- this DOES still fail, no syntax-level way to tell
#endif

  do {
    struct E: ~Escapable {
      borrowing func h() -> Bool { false }
      consuming func j() -> Bool { false }
    }

    let e = E()
    #expect(e.h())
    #expect(e.j())
  }

  let s2 = S()
  _ = try #require(.some(consume s2))

  let t = T()
  #expect(t.h(.random(in: 0 ..< 100)))
  #expect(T.j(.greatestFiniteMagnitude))
  #expect(SubexpressionShowcase.T.j(.greatestFiniteMagnitude))


  let x = 9
  let y = 11
  #expect(x == y)
  #expect(try f(x, y) == g())

  let z: Int? = nil
  let zDelta = 1
  #expect(z?.advanced(by: zDelta) != nil)

  let v: String? = nil
  #expect(v?[...] != nil)
  #expect(v?[...].first != nil)

  func k(_ x: @autoclosure () -> Bool) async -> Bool {
    x()
  }
  #expect(await k(true))

  func k2(_ x: @escaping @autoclosure () -> Bool) async -> Bool {
    x()
  }
  #expect(await k2(true))

  class NonSendableClass {
    var string: String = ""
  }
  func k3(_ x: NonSendableClass) async -> Bool {
    (x as NonSendableClass?) == nil
  }
  let nonSendableObject = NonSendableClass()
  #expect(await k3(nonSendableObject))
  extendLifetime(nonSendableObject)

#if false
  // Unsupported: __ec necessarily captures non-sendable state, so this will
  // fail to compile because it is capturing __ec in a sendable closure. We
  // could add locks guarding __ec's mutable state and eagerly capture state,
  // but that would slow down tests significantly. The type checker cannot
  // handle the number of `where T: Sendable` overloads of various functions
  // that we would need in order to provide eager capture only for non-sendable
  // values. However, this is a relatively narrow case, so for now we'll just
  // accept it as unsupported and tell affected test authors to refactor their
  // expectations so as to call m(_:) _before_ #expect().
  func m(_ x: @autoclosure @Sendable () -> Bool) -> Bool {
    x()
  }
  #expect(m(123 == 456))
#endif

  try #require(x == x)
  _ = try #require(.some(Int32.Magnitude(1)))

  let n = 1 as Any
  _ = try #require(n as? String)
}
