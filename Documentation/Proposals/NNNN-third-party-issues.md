# Improve robustness of recording Issues

* Proposal: [SWT-NNNN](NNNN-third-party-issues.md)
* Authors: [Rachel Brindle](https://github.com/younata), [Jonathan Grynspan](https://github.com/grynspan)
* Status: **Awaiting review**
* Bug: [apple/swift-testing#490](https://github.com/apple/swift-testing/issues/490)
* Implementation: [apple/swift-testing#513](https://github.com/apple/swift-testing/pull/513)
* Review: [To be added]

## Introduction

Integration with third party tools is important for the success of Swift Testing
and the ecosystem as a whole. To support this, Swift Testing should offer tools
more control over how custom issues are recorded and what is shown.

## Motivation

There are several third-party assertion libraries that developers are used to
using, and Swift Testing should make it as easy as possible for the developers
and maintainers of these third-party assertion libraries to integrate with
Swift Testing.

Swift Testing currently offers the `Issue.record` family of static methods,
which provides an acceptable interface for one-off/custom assertions without
using the `#expect` or `#require` macros. Unfortunately, the public
`Issue.record` static method does not offer a way to precisely control the
error information shown to the user - all Issues are recorded as "unconditional
failure", which is false if the Issue actually happened as the result of an
assertion failing.

## Proposed solution

We create a new public `Issue.record` static method, specifically to record and
display only the information given to it:

```swift
extension Issue {
  @discardableResult public static func record(
    _ comment: Comment? = nil,
    context toolContext: some Issue.Kind.ToolContext,
    sourceLocation: SourceLocation = #_sourceLocation
  ) -> Self
}
```

This method is then used by tools to provide a comment of what happened, as well
as information for the user to know what tool actually recorded the issue.

## Detailed design

`Issue.record` creates an issue of kind `Issue.Kind.recordedByTool`. This is a
new case specifically for this API, and serves to hold on to the
`Issue.Kind.ToolContext`. `ToolContext` is a protocol specifically to allow
test tool authors to provide information about the tool that produced the issue,
such as the name of the tool.

When displaying the Issue to the console/IDE, only the comment and toolContext
are used to generate the failure information:

```swift
struct MyToolContext: Issue.Kind.ToolContext {
    let toolName = "Sample Tool"
}

// ...
Issue.record("an example issue", context: MyToolContext())
// "an example issue (from 'Sample Tool')" would be shown to the user.
```

## Source compatibility

This is entirely additive. All existing code will continue to work.

## Integration with supporting tools

Tool integrating with the testing library need to create an object
conforming to `Issue.Kind.ToolContext` and use that with `Issue.record` to
record an issue with an arbitrary message.

But if they wish, they can still use the existing `Issue.record` API to record
unconditional failures.

## Future directions

Third-party assertion tools that already integrate with XCTest also need a
more robust API for detecting whether to report an assertion failure to XCTest
or Swift Testing. See [#475](https://github.com/apple/swift-testing/issues/475),
[apple/swift-corelibs-xctest#491](https://github.com/apple/swift-corelibs-xctest/issues/491),
and FB14167426 for issues related to that. Detecting the test runner is a
separate enough concern that it should not be part of this proposal.

## Alternatives considered

We could do nothing and require third party tools to use the existing
`Issue.record` API. However, this results in a subpar experience for developers
wishing to use those third party tools.

This proposal came out of discussion around a [previous, similar proposal](https://github.com/apple/swift-testing/pull/481)
to open up the `Issue` API and allowing arbitrary `Issue` instances to be
recorded. That proposal was dropped in favor of this one, which is significantly
simpler and opens up as little API surface as possible.

## Acknowledgments

I'd like to thank [Stuart Montgomery](https://github.com/stmontgomery) for his
help and insight leading to this proposal. Jonathan Grynspan is already
listed as an author for his role creating the implementation, but I also want to
explicitly thank him for his help and insight as well.
