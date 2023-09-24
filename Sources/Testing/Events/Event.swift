//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

/// An event that occurred during testing.
@_spi(ExperimentalEventHandling)
public struct Event: Sendable {
  /// An enumeration describing the various kinds of event that can be observed.
  public enum Kind: Sendable {
    /// A test run started.
    ///
    /// This is the first event posted after ``Runner/run()`` is called.
    @_spi(ExperimentalTestRunning)
    case runStarted

    /// A step in the runner plan started.
    ///
    /// - Parameters:
    ///   - step: The step in the runner plan which started.
    ///
    /// This is posted when a ``Runner`` begins processing a
    /// ``Runner/Plan/Step``. Processing this step may result in its associated
    /// ``Test`` being run, skipped, or another action, so this event will only
    /// be followed by a ``testStarted`` event if the step's test is run.
    @_spi(ExperimentalTestRunning)
    case planStepStarted(_ step: Runner.Plan.Step)

    /// A test started.
    case testStarted
    
    /// A test has been running for another "tick", used internally to drive
    /// be able to update ASN1 terminal code based Progress UI, like yarn.
    case testProgressTick(tick: Int)

    /// A test case started.
    @_spi(ExperimentalParameterizedTesting)
    case testCaseStarted

    /// A test case ended.
    @_spi(ExperimentalParameterizedTesting)
    case testCaseEnded

    /// An expectation was checked with `#expect()` or `#require()`.
    ///
    /// - Parameters:
    ///   - expectation: The expectation which was checked.
    ///
    /// By default, events of this kind are not generated because they occur
    /// frequently in a typical test run and can generate significant
    /// backpressure on the event handler.
    ///
    /// Failed expectations also, unless expected to fail, generate events of
    /// kind ``Event/Kind-swift.enum/issueRecorded(_:)``. Those events are
    /// always posted to the current event handler.
    ///
    /// To enable events of this kind, set
    /// ``Configuration/deliverExpectationCheckedEvents`` to `true` before
    /// running tests.
    case expectationChecked(_ expectation: Expectation)

    /// An issue was recorded.
    ///
    /// - Parameters:
    ///   - issue: The issue which was recorded.
    case issueRecorded(_ issue: Issue)

    /// A test ended.
    case testEnded

    /// A test was skipped.
    ///
    /// - Parameters:
    ///   - skipInfo: A ``SkipInfo`` containing details about this skipped test.
    case testSkipped(_ skipInfo: SkipInfo)

#if !SWIFT_PACKAGE
    @_documentation(visibility: private)
    @available(*, deprecated, renamed: "testSkipped")
    case testBypassed(_ bypassInfo: BypassInfo)
#endif

    /// A step in the runner plan ended.
    ///
    /// - Parameters:
    ///   - step: The step in the runner plan which ended.
    ///
    /// This is posted when a ``Runner`` finishes processing a
    /// ``Runner/Plan/Step``.
    @_spi(ExperimentalTestRunning)
    case planStepEnded(Runner.Plan.Step)

    /// A test run ended.
    ///
    /// This is the last event posted before ``Runner/run()`` returns.
    @_spi(ExperimentalTestRunning)
    case runEnded
  }

  /// The kind of event.
  public var kind: Kind

  /// The test for which this event occurred.
  ///
  /// If an event occurred independently of any test, or if the running test
  /// cannot be determined, the value of this property is `nil`.
  public var test: Test?

  /// The test case for which this event occurred.
  ///
  /// The test case indicates which element in the iterated sequence is
  /// associated with this event. For non-parameterized tests, a single test
  /// case is synthesized. For test suite types (as opposed to test functions),
  /// the value of this property is `nil`.
  @_spi(ExperimentalParameterizedTesting)
  public var testCase: Test.Case?

  /// The instant at which the event occurred.
  public var instant: Test.Clock.Instant

  /// Initialize an instance of this type.
  ///
  /// - Parameters:
  ///   - kind: The kind of event that occurred.
  ///   - test: The test for which the event occurred, if any.
  ///   - testCase: The test case for which the event occurred, if any.
  ///   - instant: The instant at which the event occurred. The default value
  ///     of this argument is `.now`.
  init(_ kind: Kind, for test: Test? = .current, testCase: Test.Case? = .current, instant: Test.Clock.Instant = .now) {
    self.kind = kind
    self.test = test
    self.testCase = testCase
    self.instant = instant
  }
}

// MARK: - Event handling

@_spi(ExperimentalEventHandling)
extension Event {
  /// A function that handles events that occur while tests are running.
  ///
  /// - Parameters:
  ///   - event: An event that needs to be handled.
  public typealias Handler = @Sendable (Event) -> Void

  /// Post this event to the currently-installed event handler.
  ///
  /// - Parameters:
  ///   - configuration: The configuration whose event handler should handle
  ///     this event. If `nil` is passed, the current task's configuration is
  ///     used, if known.
  ///
  /// Prefer using this function over invoking event handlers directly. If
  /// `configuration` is not `nil`, `self` is passed to its
  /// ``Configuration/eventHandler`` property. If `configuration` is `nil`, and
  /// ``Configuration/current`` is _not_ `nil`, its event handler is used
  /// instead. If there is no current configuration, the event is posted to
  /// the event handlers of all configurations set as current across all tasks
  /// in the process.
  func post(configuration: Configuration? = nil) {
    if let configuration = configuration ?? Configuration.current {
      // The caller specified a configuration, or the current task has an
      // associated configuration. Post to either configuration's event handler.
      switch kind {
      case .expectationChecked where !configuration.deliverExpectationCheckedEvents:
        break
      default:
        configuration.handleEvent(self)
      }
    } else {
      // The current task does NOT have an associated configuration. This event
      // will be lost! Post it to every registered event handler to avoid that.
      for configuration in Configuration.all {
        post(configuration: configuration)
      }
    }
  }
}
