//
//  NotificationHelpers.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation

/// Wrapper for NSNotificationCenter patterns
public protocol Listener {
    func startListening()
    func stopListening()
}

public struct ListenerSet: Listener {
    fileprivate var listeners: Set<NotificationListener>

    public init() {
        listeners = []
    }

    public mutating func addListener(_ listener: NotificationListener) {
        listeners.insert(listener)
    }

    public func startListening() {
        listeners.forEach { $0.startListening() }
    }

    public func stopListening() {
        listeners.forEach { $0.stopListening() }
    }
}

public final class NotificationListener: NSObject, Listener {

    public typealias Callback = (Notification) -> Void

    private var callback: Callback
    private var name: Notification.Name
    private var from: [AnyObject?]
    private var listening: Bool

    public convenience init(name:  Notification.Name, from: AnyObject?, callback: @escaping Callback) {
        self.init(name: name, from: [from], callback: callback)
    }

    public init(name: Notification.Name, from: [AnyObject?], callback: @escaping Callback) {
        assert(from.count > 0)
        self.callback = callback
        self.name = name
        self.from = from
        self.listening = false
        super.init()

        startListening()
    }

    public func startListening() {
        assert(!listening)
        listening = true
        let center = NotificationCenter.default
        from.forEach {
            center.addObserver(self, selector: #selector(NotificationListener.notified), name: name, object: $0)
        }
    }

    @objc public func notified(_ nf: Notification) {
        callback(nf)
    }

    public func stopListening() {
        assert(listening)
        listening = false
        let center = NotificationCenter.default
        from.forEach {
            center.removeObserver(self, name: name, object: $0)
        }
    }
}
