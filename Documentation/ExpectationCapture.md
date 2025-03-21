# Rethinking expectation capture in Swift Testing

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

<!--
This document was originally published on the Swift forums at
https://forums.swift.org/t/mini-vision-rethinking-expectation-capture-in-swift-testing/77075
-->

Since we announced Swift Testing and shipped it to developers with the Swift 6
toolchain, we've been looking at how we could improve the library. Some changes
we hope to introduce, like exit tests and attachments, are major new features.
Others are smaller quality-of-life changes (bug fixes, performance improvements,
and so on.)

### ℹ️ Be advised
This post assumes some knowledge and understanding of Swift macros and how they
work. In particular, you should know that when the Swift compiler encounters an
_expression_ of the form `#m(a, b, c)`, it passes that expression's
_abstract syntax tree_ (AST) to a compiler plugin that then replaces it with an
equivalent AST known as its _expansion_.

## Our expectations for expectations

One area we knew we'd want to revisit was the `#expect()` and `#require()`
macros and how they work. `#expect()` and `#require()` are more than just
functions: they're _expression macros_. We wrote them as expression macros so
that we could give them some special powers.

When you use one macro or the other, it examines the AST of its condition
argument and looks for one of several known kinds of expression (e.g. binary
operators, member function calls, or `is`/`as?` casts). If found, the macro
rewrites the expression in a form that Swift Testing can examine at runtime.
Then, if the expectation fails, Swift Testing can produce better diagnostics
than it could if it just treated the condition expression as a boolean value.

For example, if you write this expectation:

```swift
#expect(f() < g())
```

… Swift Testing is able to tell you the results of `f()` and `g()` in addition
to the overall expression `f() < g()`.

### Effectively ineffective macros

This works fairly well for simple expressions like that one, but it doesn't have
the flexibility needed to tell a test author what goes wrong when a more complex
expression is used. For example, this expression:

```swift
#expect(x && y && !z)
```

… is subject to a transformation called "operator folding" that takes place
prior to macro expansion, and the AST represents it as a binary operator whose
left-hand operand is _another_ binary operator. Swift Testing doesn't know how
to recursively expand the nested binary operator, so it only produces values for
`x && y` and `!z`.

We also run into trouble when effects (`try` and `await`) are in play. Swift
Testing's implementation can't readily handle arbitrary combinations of
subexpressions that may or may not need either keyword. As a result, it doesn't
try to expand expressions that contain effects. If `f()` or `g()` is a throwing
function:

```swift
#expect(try f() < g())
```

… Swift Testing will not attempt to do any further processing, and only the
outermost expression (`try f() < g()`) will be captured.

## Looking forward

Now that Swift 6.1 has branched for its upcoming release, we can start to look
at the _next_ Swift version and how we can improve Swift Testing to help make it
the _Awesomest Swift Release Ever_. And we'd like to start by revisiting how
we've implemented these macros.

We've been working on [a branch](https://github.com/swiftlang/swift-testing/tree/jgrynspan/162-redesign-value-capture)
of Swift Testing (with a corresponding [draft PR](https://github.com/swiftlang/swift-testing/pull/840))
that completely redesigns the implementation of the `#expect()` and `#require()`
macros. Instead of trying to sniff out an "interesting" expression to expand,
the code on this branch walks the AST of the condition expression and rewrites
_all_ interesting subexpressions.

This expectation:

```swift
#expect(x && y && !z)
```

Can now be fully expanded and will provide a full breakdown of the condition at
runtime if it fails:

```
◇ Test example() started.
✘ Test example() recorded an issue at Example.swift:1:2: Expectation failed: x && y && !z → false
↳ x && y && !z → false
↳   x && y → true
↳     x → true
↳     y → true
↳   !z → false
↳     z → true
✘ Test example() failed after 0.002 seconds with 1 issue.
```

## How you can help

Before we merge this PR and enable these changes in prerelease Swift toolchains,
we’d love it if you could try it out! These changes are a major change for Swift
Testing and the more feedback we can get, the better. To try out the changes:

1. _Temporarily_ add an explicit package dependency on Swift Testing and point
   Swift Package Manager or Xcode to the branch. In your Package.swift file, add
   this dependency:

   ```swift
   dependencies: [
     /* ... */
     .package(
       url: "https://github.com/swiftlang/swift-testing.git",
       branch: "jgrynspan/162-redesign-value-capture"
     ),
   ],
   ```

   And update your test target:

   ```swift
   .testTarget(
     name: "MyTests",
     dependencies: [
       /* ... */
       .productItem(name: "Testing", package: "swift-testing"),
     ]
   )
   ```

   If you’re using an Xcode project, you can add a package dependency via the
   **Package Dependencies** tab in your project’s configuration. Add the
   `Testing` target as a dependency of your test target and click
   **Trust & Enable** to use the locally-built `TestingMacros` target.

1. Once you’ve added the package dependency, clean your package
   (`swift package clean`) or project (**Product** → **Clean Build Folder…**),
   then build and run your tests.

   Swift Testing will be built from source along with swift-syntax, which may
   significantly increase your build times, so we don’t recommend doing this in
   production—this is an at-desk experiment. Swift Testing will be built with
   optimizations off by default, so runtime performance may be impacted, but
   that’s okay: we’re mostly concerned about correctness rather than raw
   performance measurements for the moment.

1. Let us know how your experience goes, especially if you run into problems.
   You can reach me by sending me [a forum DM](https://forums.swift.org/u/grynspan/summary)
   or by commenting on [this PR](https://github.com/swiftlang/swift-testing/pull/840).

## Here be caveats

There are some expressions that Swift Testing could previously successfully
expand that will cause problems with this new implementation:

- Expectations with effects where the effect keyword is to the left of the macro
  name:

  ```swift
  try #expect(h())
  ```

  Macros cannot currently "see" effect keywords in this position. The old
  implementation would often compile because the expansion didn't introduce a
  nested closure scope (which necessarily must repeat these keywords in other
  positions.) The new implementation does not know it needs to insert the `try`
  keyword anywhere in this case, resulting in some confusing diagnostics:

  > ⚠️ No calls to throwing functions occur within 'try' expression
  >
  > 🛑 Call can throw, but it is not marked with 'try' and the error is not
  > handled

  [Stuart Montgomery](https://github.com/stmontgomery) and I chatted with
  [Doug Gregor](https://github.com/DougGregor) and [Holly Borla](https://github.com/hborla)
  recently about this issue; they're looking at the problem and seeing what sort
  of compiler-side support might be possible to help solve it.

  [Stuart Montgomery](https://github.com/stmontgomery) has opened [a PR](https://github.com/swiftlang/swift-syntax/pull/2724)
  against swift-syntax that we hope will help resolve this issue.

  **To avoid this issue**, always place `try` and `await` _within_ the argument
  list of `#expect()`:

  ```swift
  #expect(try h())
  ```

  For `#require()`, the implementation knows that `try` must be present to the
  left of the macro.

- Expectations with particularly complex conditions can, after expansion,
  overwhelm the type checker and fail to compile:

  > 🛑 The compiler is unable to type-check this expression in reasonable time;
  > try breaking up the expression into distinct sub-expressions

  Because macros have little-to-no type information, there aren't a lot of
  opportunities for us to provide any in the macro expansion. I've reached out
  to [Holly Borla](https://github.com/hborla) and her colleagues to see if
  there's room for us to improve our implementation in ways that help the type
  checker.

  **If your expectation fails with this error,** break up the expression as
  recommended and only include part of the expression in the macro's argument
  list:

  ```swift
  let x = ...
  let y = ...
  #expect(x == y)
  ```

- Type names are (syntactically speaking) indistinguishable from variable names.
That means there may be some expressions that we _could_ expand further, but
because we can't tell if a syntax node refers to a variable, a type, or a
module, we don't try:

  ```swift
  #expect(a.b == c) // a may not be expressible in isolation
  ```

  Where we think we can expand such a syntax node, the macro expansion appends
  `.self` to the node in case it refers to a type. There may be cases where the
  macro expansion logic does not work as intended: please send us bug reports if
  you find them!

- The `==`, `!=`, `===`, and `!==` operators are special-cased so that we can
  use [`difference(from:)`](https://developer.apple.com/documentation/swift/bidirectionalcollection/difference(from:))
  to compare operands where possible. The macro implementation assumes that
  these operators eagerly evaluate their arguments (unlike operators like `&&`
  that short-circuit their right-hand arguments using `@autoclosure`.) This
  assumption is true of all implementations of these operators in the Swift
  Standard Library, but we can't make any real guarantees about third-party code.

  We believe that this should not be a common issue in real-world code, but
  please reach out if Swift Testing is expanding these operators incorrectly in
  your code.

### Disabling expression expansion

If you have a condition expression that you don't want expanded at all (for
instance, because the macro is incorrectly expanding it, or because its
implementation might be affected by side effects from Swift Testing), you can
cast the expression with `as Bool` or `as T?`:

```swift
let x = ...
let y = ...
#expect((x == y) as Bool)

let z: String?
let w = try #require(z as String?)
```

## Example expansions

Here (hidden behind disclosure triangles so as not to frighten children and
pets) are some before-and-after examples of how Swift Testing expands the
`#expect()` macro. I've cleaned up the whitespace to make it easier to read.

<details>
<summary><code>#expect(f() < g())</code></summary>

#### Before
```swift
Testing.__checkBinaryOperation(
  f(),
  { $0 < $1() },
  g(),
  expression: .__fromBinaryOperation(
    .__fromSyntaxNode("f()"),
    "<",
    .__fromSyntaxNode("g()")
  ),
  comments: [],
  isRequired: false,
  sourceLocation: Testing.SourceLocation.__here()
).__expected()
```

#### After
```swift
Testing.__checkCondition(
  { (__ec: inout Testing.__ExpectationContext) -> Swift.Bool in
    __ec(__ec(f(), 0x2) < __ec(g(), 0x400), 0x0)
  },
  sourceCode: [
    0x0: "f() < g()",
    0x2: "f()",
    0x400: "g()"
  ],
  comments: [],
  isRequired: false,
  sourceLocation: Testing.SourceLocation.__here()
).__expected()
```
</details>

<details>
<summary><code>#expect(x && y && !z)</code></summary>

#### Before
```swift
Testing.__checkBinaryOperation(
  x && y,
  { $0 && $1() },
  !z,
  expression: .__fromBinaryOperation(
    .__fromSyntaxNode("x && y"),
    "&&",
    .__fromSyntaxNode("!z")
  ),
  comments: [],
  isRequired: false,
  sourceLocation: Testing.SourceLocation.__here()
).__expected()
```

#### After
```swift
Testing.__checkCondition(
  { (__ec: inout Testing.__ExpectationContext) -> Swift.Bool in
    __ec(__ec(__ec(x, 0x6) && __ec(y, 0x42), 0x2) && __ec(!__ec(z, 0x1400), 0x400), 0x0)
  },
  sourceCode: [
    0x0: "x && y && !z",
    0x2: "x && y",
    0x6: "x",
    0x42: "y",
    0x400: "!z",
    0x1400: "z"
  ],
  comments: [],
  isRequired: false,
  sourceLocation: Testing.SourceLocation.__here()
).__expected()
```
</details>

<details>
<summary><code>#expect(try f() < g())</code></summary>

#### Before
```swift
Testing.__checkValue(
  try f() < g(),
  expression: .__fromSyntaxNode("try f() < g()"),
  comments: [],
  isRequired: false,
  sourceLocation: Testing.SourceLocation.__here()
).__expected()
```

#### After
```swift
try Testing.__checkCondition(
  { (__ec: inout Testing.__ExpectationContext) -> Swift.Bool in
    try __ec(__ec(f(), 0xc) < __ec(g(), 0x1004), 0x4)
  },
  sourceCode: [
    0x4: "f() < g()",
    0xc: "f()",
    0x1004: "g()"
  ],
  comments: [],
  isRequired: false,
  sourceLocation: Testing.SourceLocation.__here()
).__expected()
```
</details>

> [!NOTE]
> **What's with the hexadecimal?**
>
> You'll note that all calls to `__ec()` include an integer literal argument,
> and the `sourceCode` argument is a dictionary whose keys are integer literals
> too. These values represent the unique identifiers of each captured syntax
> node from the original AST. They uniquely encode the syntax nodes' positions
> in the tree so that we can reconstruct the (sparse) tree at runtime when a
> test fails.
>
> [I](http://github.com/grynspan) find this subtopic interesting enough to want
> to devote a whole forum thread to it, personally, but it's a bit arcane—for
> more information, see the implementation [here](https://github.com/swiftlang/swift-testing/blob/jgrynspan/162-redesign-value-capture/Sources/Testing/SourceAttribution/ExpressionID.swift)
> or feel free to reach out to me via forum DM.
