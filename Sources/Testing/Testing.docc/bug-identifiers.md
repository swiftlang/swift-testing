# Interpreting bug identifiers

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

Examine how the testing library interprets bug identifiers provided by developers.

## Overview

The testing library supports two distinct ways to identify a bug:

1. A URL linking to more information about the bug; and
2. A unique identifier in the bug's associated bug-tracking system.

- Note: "Bugs" as described in this document may also be referred to as
"issues." To avoid confusion with the ``Issue`` type in the testing library,
this document consistently refers to them as "bugs."

A bug may have both an associated URL _and_ an associated unique identifier. It
must have at least one or the other in order for the testing library to be able
to interpret it correctly.

To create an instance of ``Bug`` with a URL, use the ``Trait/bug(_:_:)`` trait.
At compile time, the testing library will validate that the given string can be
parsed as a URL according to [RFC 3986](https://www.ietf.org/rfc/rfc3986.txt).

To create an instance of ``Bug`` with a bug's unique identifier, use the
``Trait/bug(_:id:_:)-10yf5`` trait. The testing library does not require that a
bug's unique identifier match any particular format, but will interpret unique
identifiers starting with `"FB"` as referring to bugs tracked with the
[Apple Feedback Assistant](https://feedbackassistant.apple.com). For
convenience, you can also directly pass an integer as a bug's identifier using
``Trait/bug(_:id:_:)-3vtpl``.

### Examples

| Trait Function | Inferred Bug-Tracking System |
|-|-|
| `.bug(id: 12345)` | None |
| `.bug(id: "12345")` | None |
| `.bug("https://www.example.com?id=12345", id: "12345")` | None |
| `.bug("https://github.com/swiftlang/swift/pull/12345")` | [GitHub Issues for the Swift project](https://github.com/swiftlang/swift/issues) |
| `.bug("https://bugs.webkit.org/show_bug.cgi?id=12345")` | [WebKit Bugzilla](https://bugs.webkit.org/) |
| `.bug(id: "FB12345")` | Apple Feedback Assistant | <!-- SEE ALSO: rdar://104582015 -->
<!--
| `.bug(id: "#12345")` | GitHub Issues for the current repository (if hosted there) |
-->
