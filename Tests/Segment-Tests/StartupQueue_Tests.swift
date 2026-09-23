//
//  StartupQueue_Tests.swift
//  Segment-Tests
//

import XCTest
@testable import Segment

/// Captures track-event names after the full timeline, safely across threads.
private class RecordingPlugin: Plugin {
    let type: PluginType = .after
    weak var analytics: Analytics? = nil

    private let lock = NSLock()
    private var recorded = [String]()

    func execute<T: RawEvent>(event: T?) -> T? {
        if let track = event as? TrackEvent {
            lock.lock()
            recorded.append(track.event)
            lock.unlock()
        }
        return event
    }

    var names: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }
}

final class StartupQueue_Tests: XCTestCase {
    /// Bounded wait: a hang here is exactly the regression these tests guard
    /// against, so it must fail rather than block the suite.
    @discardableResult
    private func waitUntilRunning(_ analytics: Analytics, timeout: TimeInterval = 15) -> Bool {
        guard let startupQueue = analytics.find(pluginType: StartupQueue.self) else {
            XCTFail("StartupQueue plugin missing")
            return false
        }
        let deadline = Date(timeIntervalSinceNow: timeout)
        while startupQueue.running != true && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        XCTAssertTrue(startupQueue.running, "startup replay did not complete within \(timeout)s")
        return startupQueue.running
    }

    /// Events sent while the system transitions to running must never be
    /// stranded in the startup queue: they are either replayed or passed
    /// through, regardless of the thread they were sent from.
    func testNoEventLostAcrossStartupTransition() {
        let analytics = Analytics(configuration: Configuration(writeKey: "startupQueueStress")
            .flushAt(999999)
            .flushInterval(999999))
        let recorder = RecordingPlugin()
        analytics.add(plugin: recorder)

        let backgroundEvents = 100
        let mainEvents = 50
        let group = DispatchGroup()
        let backgroundQueue = DispatchQueue(label: "startupQueue.tests.producer")
        group.enter()
        backgroundQueue.async {
            for index in 0..<backgroundEvents {
                analytics.track(name: "background-\(index)")
            }
            group.leave()
        }
        for index in 0..<mainEvents {
            analytics.track(name: "main-\(index)")
        }

        guard waitUntilRunning(analytics) else { return }
        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)

        let expected = backgroundEvents + mainEvents
        let deadline = Date(timeIntervalSinceNow: 10)
        while recorder.names.count < expected && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        XCTAssertEqual(recorder.names.count, expected)
    }

    /// Events queued before startup replay in their original order, and an
    /// event sent after `running` is observed true comes after the backlog.
    func testQueuedEventsReplayInOrderBeforeLaterEvents() {
        let analytics = Analytics(configuration: Configuration(writeKey: "startupQueueOrder")
            .flushAt(999999)
            .flushInterval(999999))
        let recorder = RecordingPlugin()
        analytics.add(plugin: recorder)

        let queuedEvents = 10
        for index in 0..<queuedEvents {
            analytics.track(name: "pre-\(index)")
        }

        guard waitUntilRunning(analytics) else { return }
        analytics.track(name: "post")

        let deadline = Date(timeIntervalSinceNow: 10)
        while recorder.names.count < queuedEvents + 1 && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }

        let names = recorder.names
        XCTAssertEqual(Array(names.prefix(queuedEvents)), (0..<queuedEvents).map { "pre-\($0)" })
        XCTAssertEqual(names.last, "post")
        XCTAssertEqual(names.count, queuedEvents + 1)
    }
}
