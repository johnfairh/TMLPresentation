//
//  Log.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation
import os

/// XXX this is pretty basic, really need to bring in LogMessage from Topaz or something.

/// Wrapper for logging messages.
///
/// Wanted to use os_log() directly, and I guess will plug in here later, but the Swift
/// API is atrocious and unusable (StaticString....)
///
/// Not sure this is great really, losing all the interpolation stuff.  TBD when a usable
/// os_log wrapper shows up.
///

public protocol LogBuffer {
    mutating func log(line: String)
}

public enum Log {
    public static var enableDebugLogs = false

    public static var enableTableLogs = false

    public static var crashWhenPossible = false

    private static func logWithOsLog(message: String) {
        if #available(iOS 10.0, *) {
            os_log("oh well one day this will work")
            fatalError("Nope: \(message)")
        } else {
            logWithNsLog(message: message)
        }
    }

    public static var logBuffer: LogBuffer?

    private static func logWithNsLog(message: String) {
        logBuffer?.log(line: message)
        NSLog(message)
    }

    public static func log(_ message: String) {
        logWithNsLog(message: message)
    }

    public static func debugLog(_ message: String) {
        if enableDebugLogs {
            Log.log(message)
        }
    }

    public static func tableLog(_ message: String) {
        if enableTableLogs {
            Log.log("TBL: \(message)")
        }
    }

    public static func fatal(_ message: String) -> Never {
        Log.log(message)
        fatalError(message)
    }

    public static func assert(_ truth: Bool, message: @autoclosure () -> String = "") {
        if !truth {
            let str = message()
            fatal("Assertion failed \(str)")
        }
    }
}
