//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Runner.Plan {
  /// Write a dump of the specified step graph to a stream.
  ///
  /// - Parameters:
  ///   - stepGraph: The step graph to write to `stream`.
  ///   - stream: A stream to which the dump is written.
  ///   - indent: How many spaces to indent each level of text in the dump.
  ///   - depth: How many levels deep `stepGraph` is in the total graph.
  ///
  /// This function calls itself recursively to write its subgraph to `stream`.
  private func _dumpStepGraph(_ stepGraph: Graph<String, Step?>, to stream: inout some TextOutputStream, indent: Int, depth: Int) {
    var depth = depth
    if let value = stepGraph.value {
      // Precompute leading padding.
      let headingPadding = String(repeating: " ", count: indent * depth)
      let detailPadding = String(repeating: " ", count: indent * (depth + 1))

      // Print a basic description of this runner plan step.
      do {
        let symbol = "▿ "
        stream.write("\(headingPadding)\(symbol)\(value.test.name)\n")
      }

      // Print the source location for this test.
      do {
        stream.write("\(detailPadding)\(value.test.sourceLocation.moduleName)/\(value.test.sourceLocation)\n")
      }

      // Print the action for this runner plan step.
      switch value.action {
      case .run:
        break
      case let .skip(skipInfo):
        stream.write("\(detailPadding)This test was skipped")
        if let comment = skipInfo.comment {
          stream.write(": \"\(comment.rawValue)\"")
        }
        stream.write("\n")
      case let .recordIssue(issue):
        stream.write("\(detailPadding)An issue occurred planning for this test: \(issue)\n")
      }

      // Print traits. Special-case tags to combine them into a single trait for
      // display.
      do {
        var traits = value.test.traits.filter { !($0 is Tag.List) }
        let tags = value.test.tags.sorted(by: <)
        if !tags.isEmpty {
          traits.append(Tag.List(tags: tags))
        }
        if !traits.isEmpty {
          let traitsString: String = traits.lazy
            .map { "\(detailPadding)\($0)\n" }
            .joined()
          stream.write(traitsString)
        }
      }

      depth += 1
    }

    // Sort the graph's child nodes by their source locations, then print their
    // contents recursively. Note that if the root node has a value, the depth
    // is already incremented.
    let childGraphs = stepGraph.children.values
      .sorted { lhs, rhs in
        switch (lhs.value?.test.sourceLocation, rhs.value?.test.sourceLocation) {
        case let (.some(lhs), .some(rhs)):
          return lhs < rhs
        case (_, .some):
          return true
        default:
          return false
        }
      }
    for childGraph in childGraphs {
      _dumpStepGraph(childGraph, to: &stream, indent: indent, depth: depth)
    }
  }

  /// Write a dump of this runner plan to a stream.
  ///
  /// - Parameters:
  ///   - stream: A stream to which the dump is written.
  ///   - verbose: Whether or not to dump the contents of `self` verbosely. If
  ///     `true`, `Swift.dump(_:to:name:indent:maxDepth:maxItems:)` is called
  ///     instead of the testing library's implementation.
  ///   - indent: How many spaces to indent each level of text in the dump.
  ///
  /// This function produces a detailed dump of the runner plan suitable for
  /// inclusion in diagnostics or for display as part of a command-line
  /// interface.
  ///
  /// - Note: The output of this function is not intended to be machine-readable
  ///   and its format may change over time.
  public func dump(to stream: inout some TextOutputStream, verbose: Bool = false, indent: Int = 2) {
    if verbose {
      Swift.dump(self, to: &stream, indent: indent)
    } else {
      _dumpStepGraph(stepGraph, to: &stream, indent: indent, depth: 0)
    }
  }
}
