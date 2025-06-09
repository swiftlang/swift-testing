# Exit testing

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

@Metadata {
  @Available(Swift, introduced: 6.2)
  @Available(Xcode, introduced: 26.0)
}

Use exit tests to test functionality that might cause a test process to exit.

## Overview

Your code might contain calls to [`precondition()`](https://developer.apple.com/documentation/swift/precondition(_:_:file:line:)),
[`fatalError()`](https://developer.apple.com/documentation/swift/fatalerror(_:file:line:)),
or other functions that can cause the current process to exit. For example:

```swift
extension Customer {
  func eat(_ food: consuming some Food) {
    precondition(food.isDelicious, "Tasty food only!")
    precondition(food.isNutritious, "Healthy food only!")
    ...
  }
}
```

In this function, if `food.isDelicious` or `food.isNutritious` is `false`, the
precondition fails and Swift forces the process to exit. You can write an exit
test to validate preconditions like the ones above and to make sure that your
functions correctly catch invalid inputs.

- Note: Exit tests are available on macOS, Linux, FreeBSD, OpenBSD, and Windows.

### Create an exit test

To create an exit test, call either the ``expect(processExitsWith:observing:_:sourceLocation:performing:)``
or the ``require(processExitsWith:observing:_:sourceLocation:performing:)``
macro:

```swift
@Test func `Customer won't eat food unless it's delicious`() async {
  let result = await #expect(processExitsWith: .failure) {
    var food = ...
    food.isDelicious = false
    Customer.current.eat(food)
  }
}
```

The closure or function reference you pass to the macro is the _body_ of the
exit test. When an exit test is performed at runtime, the testing library starts
a new process with the same executable as the current process. The current task
is then suspended (as with `await`) and waits for the child process to exit.

- Note: An exit test cannot run within another exit test.

The parent process doesn't call the body of the exit test. Instead, the child
process treats the body of the exit test as its `main()` function and calls it
directly.

- Note: Because the body acts as the `main()` function of a new process, it
  can't capture any state originating in the parent process or from its lexical
  context. For example, the following exit test will fail to compile because it
  captures a variable declared outside the exit test itself:

  ```swift
  @Test func `Customer won't eat food unless it's nutritious`() async {
    let isNutritious = false
    await #expect(processExitsWith: .failure) {
      var food = ...
      food.isNutritious = isNutritious // ❌ ERROR: trying to capture state here
      Customer.current.eat(food)
    }
  }
  ```

If the body returns before the child process exits, the process exits as if
`main()` returned normally. If the body throws an error, Swift handles it as if
it were thrown from `main()` and forces the process to exit abnormally.

### Specify an exit condition

When you create an exit test, specify how you expect the child process exits by
passing an instance of ``ExitTest/Condition``:

- If you expect the exit test's body to run to completion or exit normally (for
  example, by calling [`exit(EXIT_SUCCESS)`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/exit.3.html)
  from the C standard library), pass ``ExitTest/Condition/success``.
- If you expect the body to cause the child process to exit abnormally, but the
  exact status reported by the system is not important, pass
  ``ExitTest/Condition/failure``.
- If you need to check for a specific exit code or signal, pass
  ``ExitTest/Condition/exitCode(_:)`` or ``ExitTest/Condition/signal(_:)``.

When the child process exits, the parent process resumes and compares the exit
status of the child process against the expected exit condition you passed. If
they match, the exit test passes; otherwise, it fails and the testing library
records an issue.

### Gather output from the child process

The ``expect(processExitsWith:observing:_:sourceLocation:performing:)`` and
``require(processExitsWith:observing:_:sourceLocation:performing:)`` macros
return an instance of ``ExitTest/Result`` that contains information about the
state of the child process. 

By default, the child process is configured without a standard output or
standard error stream. If your test needs to review the content of either of
these streams, pass the key path to the corresponding ``ExitTest/Result``
property to the macro:

```swift
extension Customer {
  func eat(_ food: consuming some Food) {
    print("Let's see if I want to eat \(food)...")
    precondition(food.isDelicious, "Tasty food only!")
    precondition(food.isNutritious, "Healthy food only!")
    ...
  }
}

@Test func `Customer won't eat food unless it's delicious`() async {
  let result = await #expect(
    processExitsWith: .failure,
    observing: [\.standardOutputContent]
  ) {
    var food = ...
    food.isDelicious = false
    Customer.current.eat(food)
  }
  if let result {
    #expect(result.standardOutputContent.contains(UInt8(ascii: "L")))
  }
}
```

- Note: The content of the standard output and standard error streams can
  contain any arbitrary sequence of bytes, including sequences that aren't valid
  UTF-8 and can't be decoded by [`String.init(cString:)`](https://developer.apple.com/documentation/swift/string/init(cstring:)-6kr8s).
  These streams are globally accessible within the child process, and any code
  running in an exit test may write to it including the operating system and any
  third-party dependencies you declare in your package description or Xcode
  project.

The testing library always sets ``ExitTest/Result/exitStatus`` to the actual
exit status of the child process (as reported by the system) even if you do not
pass it.
