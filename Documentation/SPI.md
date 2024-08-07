# SPI groups in Swift Testing

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

<!-- Archived from
  <https://forums.swift.org/t/spi-groups-in-swift-testing/70236> -->

This post describes the set of SPI groups used in Swift Testing. In general, two
groups of SPI exist in the testing library:

1. Interfaces that aren't needed by test authors, but which may be needed by
   tools that use the testing library such as Swift Package Manager; and
1. Interfaces that are available for test authors to use, but which are
   experimental or under active development and which may be modified or removed
   in the future.

For interfaces used to integrate with external tools, the SPI group
`@_spi(ForToolsIntegrationOnly)` is used. The name is a hint to adopters that
they should not be using such SPI if they aren't building tooling around the
testing library.

For interfaces that are experimental or under active development, the SPI group
`@_spi(Experimental)` is used. Such interfaces are intended to eventually become
public, stable API, so test authors are encouraged to hold off adopting them
until that happens.

For interfaces that are experimental _and_ that are used to integrate with
external tools, _both_ groups are specified. Such SPI is not generally meant to
be promoted to public API, but is still experimental until tools authors have a
chance to evaluate it.

## SPI stability

The testing library does **not** guarantee SPI stability for either group of
SPI.

For SPI marked `@_spi(ForToolsIntegrationOnly)`, breaking changes will be
preceded by deprecation (where possible) to allow tool authors time to migrate
to newer interfaces.

SPI marked `@_spi(Experimental)` should be assumed to be unstable. It may be
modified or removed at any time.

## API and ABI stability

When Swift Testing reaches its 1.0 release, API changes will follow the same
general rules as those in the Swift standard library: removal will be a last
resort and will always be preceded by deprecation to allow tool and test authors
time to migrate to newer interfaces.

As a general rule, ABI stability is not guaranteed by the testing library.
