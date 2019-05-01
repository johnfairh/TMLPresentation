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

extension NSFetchedResultsController {
    @objc public func issueFetch() {
        do {
            try performFetch()
        } catch {
            Log.log("Fetch failed: \(error) - pressing on")
        }
    }
}

extension NSFetchedResultsController where ResultType == NSManagedObject {
    public var asModelResultsSet: ModelResultsSet {
        return ModelResultsSet(results: ["" : self], defaultName: "")
    }
}

/// Helper to watch some results outside of a UITableView context, get a
/// coarse-grained callback when anything changes.
public final class ModelResultsWatcher<ModelObjectType: ModelObject>: NSObject, NSFetchedResultsControllerDelegate {
    private let callback: ([ModelObjectType]) -> Void
    public let modelResults: ModelResults
    public var objects: [ModelObjectType] {
        return modelResults.fetchedObjects as? [ModelObjectType] ?? []
    }

    /// Callback is made after the results have been updated.
    public init(modelResults: ModelResults, callback: @escaping ([ModelObjectType]) -> Void) {
        self.callback = callback
        self.modelResults = modelResults
        super.init()
        modelResults.delegate = self
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        callback(objects)
    }
}
