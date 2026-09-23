//
//  StartupQueue.swift
//  Segment
//
//  Created by Brandon Sneed on 6/4/21.
//

import Foundation
import Sovran

public class StartupQueue: Plugin, Subscriber {
    static let maxSize = 1000

    @Atomic public var running: Bool = false
    
    public let type: PluginType = .before
    
    public weak var analytics: Analytics? = nil {
        didSet {
            // Handle running-state changes off the main queue: replaying the
            // queued events writes each one to the event file synchronously,
            // which can block the app's main thread for the duration of a
            // disk flush. This queue must be distinct from `syncQueue`, which
            // `replayEvents` enters synchronously.
            analytics?.store.subscribe(self, queue: Self.stateQueue) { [weak self] (state: System) in
                self?.runningUpdate(state: state)
            }
        }
    }

    private static let stateQueue = DispatchQueue(label: "startupQueue.state.segment.com")
    let syncQueue = DispatchQueue(label: "startupQueue.segment.com")
    var queuedEvents = [RawEvent]()
    
    required init() { }
    
    public func execute<T: RawEvent>(event: T?) -> T? {
        guard let e = event else { return event }
        if running {
            // the timeline has started, so let the event pass.
            return event
        }
        var passthrough: T? = nil
        syncQueue.sync {
            // `running` can flip between the unsynchronized check above and
            // acquiring the queue; the final flip happens under `syncQueue`
            // with the backlog empty, so re-checking here guarantees an event
            // is either queued while replay will still drain it, or passed
            // through — never stranded. Replayed events re-enter here through
            // analytics.process while `running` is still false; they are
            // recognized by the replaying thread and passed through instead
            // of being requeued.
            if running || Thread.current === replayingThread {
                passthrough = e
                return
            }
            if queuedEvents.count >= Self.maxSize {
                // if we've exceeded the max queue size start dropping events
                queuedEvents.removeFirst()
            }
            queuedEvents.append(e)
        }
        return passthrough
    }

    // Only read or written while holding `syncQueue`. A dispatch work item
    // stays on one thread for its whole execution, so the replaying
    // invocation's reentrant calls observe their own thread here.
    private var replayingThread: Thread? = nil
}

extension StartupQueue {
    internal func runningUpdate(state: System) {
        if state.running {
            replayEvents()
        } else {
            syncQueue.sync { running = false }
        }
    }
    
    internal func replayEvents() {
        // Replay the queued events to the instance of Analytics we're working
        // with, draining in batches outside the lock: processing an event
        // re-enters execute() (which takes `syncQueue`) and is passed through
        // via the replaying-thread check, while events arriving from other
        // threads keep queueing behind the backlog in order. `running` flips
        // inside the lock only once the backlog is empty, so a concurrent
        // execute() either sees the flip and passes the event through, or
        // enqueues it for a further drain iteration.
        syncQueue.sync { replayingThread = Thread.current }
        while true {
            var batch = [RawEvent]()
            syncQueue.sync {
                batch = queuedEvents
                queuedEvents.removeAll()
                if batch.isEmpty {
                    running = true
                    replayingThread = nil
                }
            }
            if batch.isEmpty {
                break
            }
            for event in batch {
                analytics?.process(event: event)
            }
        }
    }
}
