//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Configuration {
  /// A type representing the details of feature of the testing library,
  /// including whether it's enabled (by default or explicitly) and when it was
  /// introduced.
  ///
  /// Features are uniquely identified by the value of their ``id`` property.
  struct Feature: Sendable, Identifiable {
    /// The identifier for this feature.
    ///
    /// A feature's identifier is typically a short, human readable,
    /// UpperCamelCased string. It must be unique among all features applied to
    /// the testing library, and may be passed by a user to explicitly enable
    /// the feature before it is enabled by default.
    var id: String

    /// The key path rooted at `Configuration` which may be used to modify a
    /// a setting controlling whether this feature is enabled.
    var configurationKeyPath: any WritableKeyPath<Configuration, Bool> & Sendable

    /// Whether this feature is enabled by default.
    ///
    /// The value of this property reflects the "out of the box" default
    /// enablement status of this feature. Its value does _not_ reflect whether
    /// a user explicitly enabled the feature; for that, see ``isExplicitlyEnabled``.
    ///
    /// ## See Also
    ///
    /// - ``isEnabledExplicitly``
    var isEnabledByDefault: Bool

    /// Whether this feature was explicitly enabled by a user.
    ///
    /// The value of this property reflects whether a user explicitly enabled
    /// this feature by e.g. passing an opt-in flag or toggling an opt-in
    /// setting in an integrated tool. Typically, this overrides the default
    /// enablement status indicated by the value of ``isEnabledByDefault``.
    ///
    /// ## See Also
    ///
    /// - ``isEnabledByDefault``
    var isEnabledExplicitly: Bool = false

    /// The event stream/ABI version in which this feature was, or is expected
    /// to be, first introduced.
    var versionIntroduced: Int

    fileprivate init(
      id: String,
      configurationKeyPath: any WritableKeyPath<Configuration, Bool> & Sendable,
      isEnabledByDefault: Bool,
      versionIntroduced: Int
    ) {
      self.id = id
      self.configurationKeyPath = configurationKeyPath
      self.isEnabledByDefault = isEnabledByDefault
      self.versionIntroduced = versionIntroduced
    }
  }
}

extension Configuration.Feature: Hashable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

// MARK: - Feature list

extension Configuration.Feature: CaseIterable {
  static var allCases: Set<Self> {
    [
      warningIssues,
    ]
  }

  /// The warning issues feature.
  ///
  /// ## See Also
  ///
  /// - [swiftlang/swift-testing#931](https://github.com/swiftlang/swift-testing/pull/931)
  static var warningIssues: Self {
    Self(
      id: "WarningIssues",
      configurationKeyPath: \.eventHandlingOptions.isWarningIssueRecordedEventEnabled,
      isEnabledByDefault: false,
      versionIntroduced: 1,
    )
  }
}
