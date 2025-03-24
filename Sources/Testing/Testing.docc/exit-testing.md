# Exit testing

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023–2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Use exit tests to test functionality that may cause a test process to terminate.

## Overview

Your code may contain calls to [`precondition()`](https://developer.apple.com/documentation/swift/precondition(_:_:file:line:)),
[`fatalError()`](https://developer.apple.com/documentation/swift/fatalerror(_:file:line:)),
or other functions that may cause the current process to terminate. For example:

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
precondition will fail and Swift will terminate the process. You can write an
exit test to validate preconditions like the ones above and to make sure that
your functions correctly catch invalid inputs.

## Create an exit test

To create an exit test, call either the ``expect(exitsWith:observing:_:sourceLocation:performing:)``
or the ``require(exitsWith:observing:_:sourceLocation:performing:)`` macro and
pass a closure containing the code that may terminate the process along with the
expected result of calling that code (success, failure, or a specific exit code
or signal):

```swift
@Test func `Customer won't eat food unless it's delicious`() async {
  let result = await #expect(exitsWith: .failure) {
    var food = ...
    food.isDelicious = false
    Customer.current.eat(food)
  }
}
```

When an exit test is performed at runtime, the testing library starts a new
process with the same executable as the current process. The current task is
then suspended (as with `await`) and waits for the child process to terminate.
`expression` is not called in the parent process.

Meanwhile, in the child process, the closure you passed to ``expect(exitsWith:observing:_:sourceLocation:performing:)``
or to ``require(exitsWith:observing:_:sourceLocation:performing:)`` is called
directly. To ensure a clean environment for execution, the closure is not called
within the context of the original test. Instead, it is treated as if it were
the `main()` function of the child process.

If the closure returns before the child process terminates, it is terminated
automatically (as if the main function of the child process were allowed to
return naturally.) If an error is thrown from the closure, it is handed as if
the error were thrown from `main()` and the process is terminated.

Once the child process terminates, the parent process resumes and compares its
exit status against the expected exit condition you passed. If they match, the
exit test has passed; otherwise, it has failed and an issue is recorded.

## Gather output from the child process

By default, the child process is configured without a standard output or
standard error stream. If your test needs to review the content of either of
these streams, you can pass its key path in the `observedValues` argument:

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
    exitsWith: .failure,
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

- Note: The content of the standard output and standard error streams may
  contain any arbitrary sequence of bytes, including sequences that are not
  valid UTF-8 and cannot be decoded by [`String.init(cString:)`](https://developer.apple.com/documentation/swift/string/init(cstring:)-6kr8s).
  These streams are globally accessible within the child process, and any code
  running in an exit test may write to it including the operating system and any
  third-party dependencies you have declared in your package.

The actual exit condition of the child process is always reported by the testing
library even if you do not specify it in `observedValues`.

## Constraints on exit tests

### State cannot be captured

Exit tests cannot capture any state originating in the parent process or from
the enclosing lexical context. For example, the following exit test will fail to
compile because it captures a variable declared outside the exit test itself:

```swift
@Test func `Customer won't eat food unless it's nutritious`() async {
  let isNutritious = false
  await #expect(exitsWith: .failure) {
    var food = ...
    food.isNutritious = isNutritious // ❌ ERROR: trying to capture state here
    Customer.current.eat(food)
  }
}
```

### Exit tests cannot be nested

An exit test cannot run within another exit test.
