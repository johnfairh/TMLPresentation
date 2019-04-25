//
//  TMLError.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

/// Simple wrapper of an error string to use with `Result`
public struct TMLError: Error, ExpressibleByStringLiteral, CustomStringConvertible {
    public let text: String

    public init(stringLiteral text: String) {
        self.text = text
    }

    public init(_ text: String) {
        self.init(stringLiteral: text)
    }

    public var description: String {
        return text
    }
}

/// Simplification for result types
public typealias TMLResult<Success> = Result<Success, TMLError>
