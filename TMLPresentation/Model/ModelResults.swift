//
//  ModelProvider.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation
import CoreData

/// Querying the model most usefully returns a set of objects.
/// As an NSFetchedResultsController this set updates live as the model changes.
public typealias ModelResults = NSFetchedResultsController<NSManagedObject>

/// A set of results -- typically of the same type of modelobject -- keyed by a string identifier
public typealias NamedModelResults = Dictionary<String, ModelResults>

/// A set of results to display in a ???ModelQueryTable???.
/// Includes a set of results that the user can choose between using their identifiers, and
/// a default that should be shown if the user has no preference.
public struct ModelResultsSet {
    public let resultsSet: NamedModelResults
    public let defaultName: String

    public init(results: NamedModelResults, defaultName: String) {
        assert(results.index(forKey: defaultName) != nil)
        self.resultsSet = results
        self.defaultName = defaultName
    }
}

extension NSFetchedResultsController where ResultType == NSManagedObject {
    public var asModelResultsSet: ModelResultsSet {
        return ModelResultsSet(results: ["" : self], defaultName: "")
    }
}

/// Alias for a live set of results of one field from an entity
public typealias ModelFieldResults = NSFetchedResultsController<NSDictionary>

/// A helper type to decode field-based results.
///
/// This can't be an extension because of objc vs. the generic
/// parameter on `getFields`.
public struct ModelFieldResultsDecoder {
    /// The FetchedResultsController
    public let results: ModelFieldResults

    /// Create an instance.
    /// Caller is responsible for creating and issuing fetches on the FRC.
    /// FRC doesn't support field queries + change tracking, caller must manually
    /// call `refresh`.
    public init(results: ModelFieldResults) {
        self.results = results
    }

    /// Query the DB and refresh the field list.  Errors are swallowed.
    public func refresh() {
        do {
            try results.performFetch()
        } catch {
            Log.log("Field results fetch failed: \(error) - pressing on")
        }
    }

    private var fields: [Any] {
        guard let objects = results.fetchedObjects else {
            return []
        }
        return objects.compactMap { dict in
            let values = dict.allValues
            return values.count == 0 ? nil : values[0]
        }
    }

    /// Get the fields in some native type
    public func getFields<T>() -> [T] {
        guard let strings = fields as? [T] else {
            return []
        }
        return strings
    }
}
