//
//  FoundationHelpers.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation

/// Helper for date manipulation
extension Date {

    /// 24h earlier.
    public var previousDay: Date {
        let calendar = Calendar.current

        guard let day = calendar.date(byAdding: .day, value: -1, to: self) else {
            Log.fatal("Can't go backwards")
        }

        return day
    }
}

/// Wrapper for simple GCD tasks
public enum Dispatch {

    public static func toBackground( _ block: @escaping ()->() ) {
        DispatchQueue.global().async(execute: block )
    }

    public static func toForeground(_ block: @escaping ()->()) {
        DispatchQueue.main.async(execute: block )
    }

    public static func toForegroundAfter(_ seconds: Int64, block: @escaping ()->()) {
        let nanoseconds = seconds * Int64(NSEC_PER_SEC)
        let when = DispatchTime.now() + Double(nanoseconds) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: when, execute: block)
    }
}

public enum Prefs {
    public static func set(_ pref: String, to value: Bool) {
        UserDefaults.standard.set(value, forKey: pref)
    }

    public static func bool(_ pref: String) -> Bool {
        return UserDefaults.standard.bool(forKey: pref)
    }
}
