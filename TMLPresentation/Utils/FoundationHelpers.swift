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

    public static func toForegroundAfter(seconds: Int64, block: @escaping ()->()) {
        toForegroundAfter(milliseconds: seconds * 1000, block: block)
    }

    public static func toForegroundAfter(milliseconds: Int64, block: @escaping ()->()) {
        let nanoseconds = milliseconds * Int64(NSEC_PER_MSEC)
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

    public static func set(_ pref: String, to value: Int) {
        UserDefaults.standard.set(value, forKey: pref)
    }

    public static func int(_ pref: String) -> Int {
        return UserDefaults.standard.integer(forKey: pref)
    }

    public static func set(_ pref: String, to value: String) {
        UserDefaults.standard.set(value, forKey: pref)
    }

    public static func string(_ pref: String) -> String {
        return UserDefaults.standard.string(forKey: pref) ?? ""
    }
}

// MARK: - FileManager

extension FileManager {
    /// Get a new temporary directory.  Caller must delete.
    public func newTemporaryDirectoryURL() throws -> URL {
        let directoryURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try createDirectory(at: directoryURL, withIntermediateDirectories: false)
        return directoryURL
    }

    /// Get a new temporary file.  Caller must delete.
    /// - parameter extension: Should not start with a dot.
    public func temporaryFileURL(inDirectory directory: URL? = nil, extension: String? = nil) -> URL {
        var filename = UUID().uuidString
        if let ext = `extension` {
            filename.append(".\(ext)")
        }
        let directoryURL = directory ?? temporaryDirectory
        return directoryURL.appendingPathComponent(filename)
    }
}

public struct TemporaryDirectory {
    public private(set) var directoryURL: URL?

    public var exists: Bool {
        return directoryURL != nil
    }

    public mutating func createNewFile() throws -> URL {
        if directoryURL == nil {
            directoryURL = try FileManager.default.newTemporaryDirectoryURL()
        }
        return FileManager.default.temporaryFileURL(inDirectory: directoryURL)
    }

    public mutating func deleteAll() {
        if let directoryURL = directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
            self.directoryURL = nil
        }
    }
}

