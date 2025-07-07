//
//  PollingConfiguration.swift
//  swift-testing
//
//  Created by Rachel Brindle on 6/6/25.
//

/// A trait to provide a default polling configuration to all usages of
/// ``confirmPassesEventually`` within a test or suite.
///
/// To add this trait to a test, use the
/// ``Trait/confirmPassesEventuallyDefaults`` function.
@_spi(Experimental)
@available(macOS 13, iOS 17, watchOS 9, tvOS 17, visionOS 1, *)
public struct ConfirmPassesEventuallyConfigurationTrait: TestTrait, SuiteTrait {
  public var pollingDuration: Duration?
  public var pollingInterval: Duration?

  public var isRecursive: Bool { true }

  public init(pollingDuration: Duration?, pollingInterval: Duration?) {
    self.pollingDuration = pollingDuration
    self.pollingInterval = pollingInterval
  }
}

/// A trait to provide a default polling configuration to all usages of
/// ``confirmAlwaysPasses`` within a test or suite.
///
/// To add this trait to a test, use the ``Trait/confirmAlwaysPassesDefaults``
/// function.
@_spi(Experimental)
@available(macOS 13, iOS 17, watchOS 9, tvOS 17, visionOS 1, *)
public struct ConfirmAlwaysPassesConfigurationTrait: TestTrait, SuiteTrait {
  public var pollingDuration: Duration?
  public var pollingInterval: Duration?

  public var isRecursive: Bool { true }

  public init(pollingDuration: Duration?, pollingInterval: Duration?) {
    self.pollingDuration = pollingDuration
    self.pollingInterval = pollingInterval
  }
}

@_spi(Experimental)
@available(macOS 13, iOS 17, watchOS 9, tvOS 17, visionOS 1, *)
extension Trait where Self == ConfirmPassesEventuallyConfigurationTrait {
  /// Specifies defaults for ``confirmPassesEventually`` in the test or suite.
  ///
  /// - Parameters:
  ///   - pollingDuration: The expected amount of times to continue polling for.
  ///     This value may not correspond to the wall-clock time that polling lasts for, especially
  ///     on highly-loaded systems with a lot of tests running.
  ///     if nil, polling will be attempted for approximately 1 second.
  ///     `pollingDuration` must be greater than 0.
  ///   - pollingInterval: The minimum amount of time to wait between polling
  ///     attempts.
  ///     If nil, polling will wait at least 1 millisecond between polling
  ///     attempts.
  ///     `pollingInterval` must be greater than 0.
  public static func confirmPassesEventuallyDefaults(
    pollingDuration: Duration? = nil,
    pollingInterval: Duration? = nil
  ) -> Self {
    ConfirmPassesEventuallyConfigurationTrait(
      pollingDuration: pollingDuration,
      pollingInterval: pollingInterval
    )
  }
}

@_spi(Experimental)
@available(macOS 13, iOS 17, watchOS 9, tvOS 17, visionOS 1, *)
extension Trait where Self == ConfirmAlwaysPassesConfigurationTrait {
  /// Specifies defaults for ``confirmPassesAlways`` in the test or suite.
  ///
  /// - Parameters:
  ///   - pollingDuration: The expected amount of times to continue polling for.
  ///     This value may not correspond to the wall-clock time that polling lasts for, especially
  ///     on highly-loaded systems with a lot of tests running.
  ///     if nil, polling will be attempted for approximately 1 second.
  ///     `pollingDuration` must be greater than 0.
  ///   - pollingInterval: The minimum amount of time to wait between polling
  ///     attempts.
  ///     If nil, polling will wait at least 1 millisecond between polling
  ///     attempts.
  ///     `pollingInterval` must be greater than 0.
  public static func confirmAlwaysPassesDefaults(
    pollingDuration: Duration? = nil,
    pollingInterval: Duration? = nil
  ) -> Self {
    ConfirmAlwaysPassesConfigurationTrait(
      pollingDuration: pollingDuration,
      pollingInterval: pollingInterval
    )
  }
}
