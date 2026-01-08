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
  let fff = false
  let ttt = true
  #expect(false || true)

  #expect((fff == ttt) == ttt)

  #expect((Int)(123) == 124)
  #expect((Int, Double)(123, 456.0) == (124, 457.0))
  #expect((123, 456) == (789, 0x12))
  #expect((try g() > 500) && true)

  #expect(!Bool(true))

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
#if SWT_EXPERIMENTAL_REF_TYPE_ENABLED
  // Unsupported: move-only types have too many constraints that cannot be
  // resolved by inspecting syntax. Borrowing calls cannot be boxed (at least
  // until we get @lifetime) and the compiler forbids making consuming calls in
  // a closure in case the closure gets called multiple times.
  //
  // A workaround is to explicitly write `consume` on an expression (or the
  // unsupported `_borrow`) which will tell our macros code not to try expanding
  // the expression.
  let s = S()
  #expect(s.h())
#if false
  #expect(s.j()) // consuming -- this DOES still fail, no syntax-level way to tell
#endif
#endif

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
