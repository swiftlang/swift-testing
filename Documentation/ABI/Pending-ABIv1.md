# Pending ABIv1 Changes

This document collects changes which have been made and are anticipated to be
released in a future ABI/event stream version, but are still pending.

> [!IMPORTANT]
> This file describes changes which are unreleased, and are subject to change.
> Do not depend on this version or make assumptions that these changes will
> remain part of this ABI version.

## Schema version numbers

The schema version can now be specified as a 2- or 3-part version string such as
`"6.3"`. Integers continue to be supported for backwards-compatibility with the
existing "version 0" and Xcode 16 Beta schemas.

```diff
-<version> ::= "version": 0 ; will be incremented as the format changes
+<version> ::= "version": <version-number>
+
+<version-number> ::= 0 | "<integer>.<integer>" | "<integer>.<integer>.<integer>"
```

## Issue severity and warning issues

Introduced a notion of "severity" for issues, and a new "warning" severity level
which is lower than the default "error" level. Clients upgrading from v0 should
begin consulting the severity of recorded issues to determine whether the
associated test should be marked as failing.

```diff
 <issue> ::= {
   "isKnown": <bool>, ; is this a known issue or not?
+  "severity": <issue-severity>, ; the severity of the issue
+  "isFailure": <bool>, ; did this issue cause the associated test to fail?
   ["sourceLocation": <source-location>,] ; where the issue occurred, if known
 }

+<issue-severity> ::= "warning" | "error"
+  ; additional severities may be added in the future
```

### See Also

- https://github.com/swiftlang/swift-testing/pull/931
