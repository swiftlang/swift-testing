//
//  Issue+Recording.swift
//  swift-testing
//
//  Created by Rachel Brindle on 11/2/26.
//

public import Testing

extension Issue {
  /// Record this issue to the testing Library.
  ///
  /// - Returns: The issue that was recorded (`self` or a modified copy of it.)
  public func record() -> Self {
    self.record(configuration: nil)
  }
}
