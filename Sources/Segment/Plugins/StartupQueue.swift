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
        if running == false, let e = event  {
            // timeline hasn't started, so queue it up.
            syncQueue.sync {
                if queuedEvents.count >= Self.maxSize {
                    // if we've exceeded the max queue size start dropping events
                    queuedEvents.removeFirst()
                }
                queuedEvents.append(e)
            }
            return nil
        }
        // the timeline has started, so let the event pass.
        return event
    }
}

extension StartupQueue {
    internal func runningUpdate(state: System) {
        running = state.running
        if state.running {
            replayEvents()
        }
    }
    
    internal func replayEvents() {
        // replay the queued events to the instance of Analytics we're working with.
        syncQueue.sync {
            for event in queuedEvents {
                analytics?.process(event: event)
            }
            queuedEvents.removeAll()
        }
    }
}
