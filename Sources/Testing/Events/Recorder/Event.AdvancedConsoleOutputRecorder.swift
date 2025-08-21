//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

extension Event {
  /// An experimental console output recorder that provides enhanced test result
  /// display capabilities.
  ///
  /// This recorder is currently experimental and must be enabled via the
  /// `SWT_ENABLE_EXPERIMENTAL_CONSOLE_OUTPUT` environment variable.
  struct AdvancedConsoleOutputRecorder<V: ABI.Version>: Sendable {
    /// Configuration options for the advanced console output recorder.
    struct Options: Sendable {
      /// Base console output recorder options to inherit from.
      var base: Event.ConsoleOutputRecorder.Options
      
      init() {
        self.base = Event.ConsoleOutputRecorder.Options()
      }
    }
    
    /// Context for storing data across events during test execution.
    private struct _Context: Sendable {
      /// Storage for test information, keyed by test ID string value.
      /// This is needed because ABI.EncodedEvent doesn't contain full test context.
      var testStorage: [String: ABI.EncodedTest<V>] = [:]
      
      /// Hierarchical test node structure for building the test tree.
      var testHierarchy: _TestNode? = nil
      
      /// Test results keyed by test ID string for tracking outcomes.
      var testResults: [String: _TestResult] = [:]
      
      /// Issues recorded during test execution, keyed by test ID string.
      var testIssues: [String: [ABI.EncodedIssue<V>]] = [:]
      
      /// Test timing information for duration display.
      var testTimings: [String: (start: ABI.EncodedInstant<V>?, end: ABI.EncodedInstant<V>?)] = [:]
    }
    
    /// Represents a node in the test hierarchy tree.
    private struct _TestNode: Sendable {
      let testID: String
      let name: String
      let isSuite: Bool
      var children: [_TestNode] = []
      var parent: String? = nil
      
      init(testID: String, name: String, isSuite: Bool) {
        self.testID = testID
        self.name = name
        self.isSuite = isSuite
      }
    }
    
    /// Represents the result of a test execution.
    private enum _TestResult: Sendable {
      case passed
      case failed
      case skipped
      case unknown
    }
    
    /// The options for this recorder.
    let options: Options
    
    /// The write function for this recorder.
    let write: @Sendable (String) -> Void
    
    /// The fallback console recorder for standard output.
    private let _fallbackRecorder: Event.ConsoleOutputRecorder
    
    /// Context storage for test information and results.
    private let _context: Locked<_Context>
    
    /// Human-readable output recorder for generating messages.
    private let _humanReadableRecorder: Event.HumanReadableOutputRecorder
    
    /// Initialize the advanced console output recorder.
    ///
    /// - Parameters:
    ///   - options: Configuration options for the recorder.
    ///   - write: A closure that writes output to its destination.
    init(options: Options = Options(), writingUsing write: @escaping @Sendable (String) -> Void) {
      self.options = options
      self.write = write
      self._fallbackRecorder = Event.ConsoleOutputRecorder(options: options.base, writingUsing: write)
      self._context = Locked(rawValue: _Context())
      self._humanReadableRecorder = Event.HumanReadableOutputRecorder()
    }
  }
}

extension Event.AdvancedConsoleOutputRecorder {
  /// Record an event by processing it and generating appropriate output.
  ///
  /// This implementation converts the Event to ABI.EncodedEvent for internal processing,
  /// following the ABI-based architecture for future separation into a harness process.
  ///
  /// - Parameters:
  ///   - event: The event to record.
  ///   - eventContext: The context associated with the event.
  func record(_ event: borrowing Event, in eventContext: borrowing Event.Context) {
    // Handle test discovery to populate our test storage and build hierarchy
    if case .testDiscovered = event.kind, let test = eventContext.test {
      let encodedTest = ABI.EncodedTest<V>(encoding: test)
      _context.withLock { context in
        context.testStorage[encodedTest.id.stringValue] = encodedTest
        _buildTestHierarchy(encodedTest, in: &context)
      }
    }
    
    // Generate human-readable messages for the event
    let messages = _humanReadableRecorder.record(event, in: eventContext)
    
    // Convert Event to ABI.EncodedEvent
    if let encodedEvent = ABI.EncodedEvent<V>(encoding: event, in: eventContext, messages: messages) {
      // Process the ABI event for hierarchical tracking
      _processABIEvent(encodedEvent)
    }
    
    // For now, still delegate to the fallback recorder to maintain existing functionality
    _fallbackRecorder.record(event, in: eventContext)
  }
  
  /// Process an ABI.EncodedEvent for advanced console output.
  ///
  /// This is where the enhanced console logic will be implemented in future PRs.
  /// Currently this is a placeholder that demonstrates the ABI conversion.
  ///
  /// - Parameters:
  ///   - encodedEvent: The ABI-encoded event to process.
  private func _processABIEvent(_ encodedEvent: ABI.EncodedEvent<V>) {
    _context.withLock { context in
      switch encodedEvent.kind {
      case .runStarted:
        // Initialize hierarchy for the test run
        break
      case .testStarted:
        // Track test start time
        if let testID = encodedEvent.testID?.stringValue {
          context.testTimings[testID] = (start: encodedEvent.instant, end: nil)
        }
      case .issueRecorded:
        // Record issues for failure summary
        if let testID = encodedEvent.testID?.stringValue,
           let issue = encodedEvent.issue {
          if context.testIssues[testID] == nil {
            context.testIssues[testID] = []
          }
          context.testIssues[testID]?.append(issue)
        }
      case .testEnded:
        // Track test end time and determine result
        if let testID = encodedEvent.testID?.stringValue {
          var timing = context.testTimings[testID] ?? (start: nil, end: nil)
          timing.end = encodedEvent.instant
          context.testTimings[testID] = timing
          
          // Determine test result based on issues
          let hasFailures = context.testIssues[testID]?.contains { !$0.isKnown } ?? false
          context.testResults[testID] = hasFailures ? .failed : .passed
        }
      case .testSkipped:
        // Mark test as skipped
        if let testID = encodedEvent.testID?.stringValue {
          context.testResults[testID] = .skipped
        }
      case .runEnded:
        // Generate and output failure summary
        _generateFailureSummary(context: context)
      default:
        // Handle other event types
        break
      }
    }
  }
  
  /// Build the test hierarchy from discovered tests.
  ///
  /// - Parameters:
  ///   - encodedTest: The test to add to the hierarchy.
  ///   - context: The mutable context to update.
  private func _buildTestHierarchy(_ encodedTest: ABI.EncodedTest<V>, in context: inout _Context) {
    let testID = encodedTest.id.stringValue
    
    // Create test node - use the test name and kind
    let testName = encodedTest.displayName ?? encodedTest.name
    let isSuite = encodedTest.kind == .suite
    let testNode = _TestNode(testID: testID, name: testName, isSuite: isSuite)
    
    // For now, store as a flat list - we'll build the tree structure later
    // This is a simplified approach for the initial implementation
    if context.testHierarchy == nil {
      context.testHierarchy = testNode
    }
    // TODO: Implement proper tree building logic in next iteration
  }
  
  /// Generate and output the failure summary.
  ///
  /// - Parameters:
  ///   - context: The context containing test results and hierarchy.
  private func _generateFailureSummary(context: _Context) {
    var output = "\n"
    output += "Test Summary:\n"
    
    // Find all failed tests
    let failedTests = context.testResults.compactMap { (testID, result) -> (String, ABI.EncodedTest<V>)? in
      guard result == .failed, let test = context.testStorage[testID] else { return nil }
      return (testID, test)
    }
    
    if failedTests.isEmpty {
      output += "All tests passed! ✅\n"
    } else {
      output += "\nFailures:\n"
      
      for (testID, test) in failedTests {
        // Basic failure display - will enhance with hierarchy later
        output += "├─ ❌ \(test.displayName ?? test.name)\n"
        
        // Show issues for this test
        if let issues = context.testIssues[testID] {
          for issue in issues where !issue.isKnown {
            let issueText = issue._error?.description ?? "Test failure"
            output += "│  └─ \(issueText)\n"
          }
        }
      }
    }
    
    write(output)
  }
}
