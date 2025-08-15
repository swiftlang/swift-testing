//
//  PollingConfiguration.swift
//  swift-testing
//
//  Created by Rachel Brindle on 6/6/25.
//

/// A trait to provide a default polling configuration to all usages of
/// ``confirmation(_:until:within:pollingEvery:isolation:sourceLocation:_:)-455gr``
/// and
/// ``confirmation(_:until:within:pollingEvery:isolation:sourceLocation:_:)-5tnlk``
/// within a test or suite for the ``PollingStopCondition.firstPass``
/// stop condition.
///
/// To add this trait to a test, use the
/// ``Trait/pollingUntilFirstPassDefaults`` function.
@_spi(Experimental)
@available(_clockAPI, *)
public struct PollingUntilFirstPassConfigurationTrait: TestTrait, SuiteTrait {
  /// How long to continue polling for
  public var duration: Duration?
  /// The minimum amount of time to wait between polling attempts
  public var interval: Duration?

  public var isRecursive: Bool { true }

  public init(duration: Duration?, interval: Duration?) {
    self.duration = duration
    self.interval = interval
  }
}

/// A trait to provide a default polling configuration to all usages of
/// ``confirmation(_:until:within:pollingEvery:isolation:sourceLocation:_:)-455gr``
/// and
/// ``confirmation(_:until:within:pollingEvery:isolation:sourceLocation:_:)-5tnlk``
/// within a test or suite for the ``PollingStopCondition.stopsPassing``
/// stop condition.
///
/// To add this trait to a test, use the ``Trait/pollingUntilStopsPassingDefaults``
/// function.
@_spi(Experimental)
@available(_clockAPI, *)
public struct PollingUntilStopsPassingConfigurationTrait: TestTrait, SuiteTrait {
  /// How long to continue polling for
  public var duration: Duration?
  /// The minimum amount of time to wait between polling attempts
  public var interval: Duration?

  public var isRecursive: Bool { true }

  public init(duration: Duration?, interval: Duration?) {
    self.duration = duration
    self.interval = interval
  }
}

@_spi(Experimental)
@available(_clockAPI, *)
extension Trait where Self == PollingUntilFirstPassConfigurationTrait {
  /// Specifies defaults for ``confirmPassesEventually`` in the test or suite.
  ///
  /// - Parameters:
  ///   - duration: The expected length of time to continue polling for.
  ///     This value may not correspond to the wall-clock time that polling
  ///     lasts for, especially on highly-loaded systems with a lot of tests
  ///     running.
  ///     if nil, polling will be attempted for approximately 1 second.
  ///     `duration` must be greater than 0.
  ///   - interval: The minimum amount of time to wait between polling
  ///     attempts.
  ///     If nil, polling will wait at least 1 millisecond between polling
  ///     attempts.
  ///     `interval` must be greater than 0.
  public static func pollingUntilFirstPassDefaults(
    until duration: Duration? = nil,
    pollingEvery interval: Duration? = nil
  ) -> Self {
    PollingUntilFirstPassConfigurationTrait(
      duration: duration,
      interval: interval
    )
  }
}

@_spi(Experimental)
@available(_clockAPI, *)
extension Trait where Self == PollingUntilStopsPassingConfigurationTrait {
  /// Specifies defaults for ``confirmPassesAlways`` in the test or suite.
  ///
  /// - Parameters:
  ///   - duration: The expected length of time to continue polling for.
  ///     This value may not correspond to the wall-clock time that polling
  ///     lasts for, especially on highly-loaded systems with a lot of tests
  ///     running.
  ///     if nil, polling will be attempted for approximately 1 second.
  ///     `duration` must be greater than 0.
  ///   - interval: The minimum amount of time to wait between polling
  ///     attempts.
  ///     If nil, polling will wait at least 1 millisecond between polling
  ///     attempts.
  ///     `interval` must be greater than 0.
  public static func pollingUntilStopsPassingDefaults(
    until duration: Duration? = nil,
    pollingEvery interval: Duration? = nil
  ) -> Self {
    PollingUntilStopsPassingConfigurationTrait(
      duration: duration,
      interval: interval
    )
  }
}
