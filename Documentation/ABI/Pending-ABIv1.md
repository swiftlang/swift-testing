# Pending ABIv1 Changes

This document collects changes which have been made and are anticipated to be
released in a future ABI/event stream version, but are still pending.

> [!IMPORTANT]
> This file describes changes which are unreleased, and are subject to change.
> Do not depend on this version or make assumptions that these changes will
> remain part of this ABI version.

## Issue severity and warning issues.

Introduced a notion of "severity" for issues, and a new "warning" severity level
which is lower than the default "error" level. Clients upgrading from v0 should
begin consulting the severity of recorded issues to determine whether the
associated test should be marked as failing.

### See Also

- https://github.com/swiftlang/swift-testing/pull/931
