# Handling issues with traits

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

@Metadata {
  @Available(Swift, introduced: 6.2)
  @Available(Xcode, introduced: 26.0)
}

Filter or transform issues recorded by a test.

## Overview

Use ``Trait/filterIssues(_:)`` and ``Trait/compactMapIssues(_:)`` when you need
to change how recorded issues appear in test results. These traits run for each
issue a test records and can suppress an issue or replace it with a different
one.

- Note: To mark an expected failure without rewriting the recorded issue, prefer
  `withKnownIssue()`. See <doc:known-issues>.

### Filter issues

``Trait/filterIssues(_:)`` keeps an issue when its predicate returns `true` and
suppresses it when the predicate returns `false`:

```swift
@Test(.filterIssues { issue in
  !issue.description.contains("propane")
})
func grillStarts() throws {
  try FoodTruck.shared.grill.start()
}
```

### Transform issues

``Trait/compactMapIssues(_:)`` maps each recorded issue to another issue, or to
`nil` to suppress it:

```swift
@Test(
  .compactMapIssues { issue in
    var issue = issue
    issue.comments.append("Check the propane tank.")
    return issue
  }
)
func grillStarts() throws {
  try FoodTruck.shared.grill.start()
}
```

### Inheritance and ordering

You can apply these traits to a suite. Contained tests inherit them, and if more
than one issue-handling trait applies, the testing library invokes their
closures from the innermost trait to the outermost. If a closure suppresses an
issue (`filterIssues` returns `false`, or `compactMapIssues` returns `nil`),
later outer traits do not run for that issue.

Issue-handling traits never receive issues whose kind is
``Issue/Kind-swift.enum/system``, and ``Trait/compactMapIssues(_:)`` must not
return a system issue.

## See Also

- <doc:known-issues>
- ``IssueHandlingTrait``
- ``Trait/filterIssues(_:)``
- ``Trait/compactMapIssues(_:)``
