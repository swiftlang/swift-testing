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
  public var maxPollingIterations: Int?
  public var pollingInterval: Duration?

  public var isRecursive: Bool { true }

  public init(maxPollingIterations: Int?, pollingInterval: Duration?) {
    self.maxPollingIterations = maxPollingIterations
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
  public var maxPollingIterations: Int?
  public var pollingInterval: Duration?

  public var isRecursive: Bool { true }

  public init(maxPollingIterations: Int?, pollingInterval: Duration?) {
    self.maxPollingIterations = maxPollingIterations
    self.pollingInterval = pollingInterval
  }
}

@_spi(Experimental)
@available(macOS 13, iOS 17, watchOS 9, tvOS 17, visionOS 1, *)
extension Trait where Self == ConfirmPassesEventuallyConfigurationTrait {
  /// Specifies defaults for ``confirmPassesEventually`` in the test or suite.
  ///
  /// - Parameters:
  ///   - maxPollingIterations: The maximum amount of times to attempt polling.
  ///     If nil, polling will be attempted up to 1000 times.
  ///     `maxPollingIterations` must be greater than 0.
  ///   - pollingInterval: The minimum amount of time to wait between polling
  ///     attempts.
  ///     If nil, polling will wait at least 1 millisecond between polling
  ///     attempts.
  ///     `pollingInterval` must be greater than 0.
  public static func confirmPassesEventuallyDefaults(
    maxPollingIterations: Int? = nil,
    pollingInterval: Duration? = nil
  ) -> Self {
    ConfirmPassesEventuallyConfigurationTrait(
      maxPollingIterations: maxPollingIterations,
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
  ///   - maxPollingIterations: The maximum amount of times to attempt polling.
  ///     If nil, polling will be attempted up to 1000 times.
  ///     `maxPollingIterations` must be greater than 0.
  ///   - pollingInterval: The minimum amount of time to wait between polling
  ///     attempts.
  ///     If nil, polling will wait at least 1 millisecond between polling
  ///     attempts.
  ///     `pollingInterval` must be greater than 0.
  public static func confirmAlwaysPassesDefaults(
    maxPollingIterations: Int? = nil,
    pollingInterval: Duration? = nil
  ) -> Self {
    ConfirmAlwaysPassesConfigurationTrait(
      maxPollingIterations: maxPollingIterations,
      pollingInterval: pollingInterval
    )
  }
}
