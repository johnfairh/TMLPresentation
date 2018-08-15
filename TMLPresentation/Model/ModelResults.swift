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

//
// This is roughly like `NSFetchedResultsController` but for a field
// request, ie. when the `NSFetchRequest` is using `.dictionaryResultType`
// in order to perform some shenanigans at the SQL level like summing a
// field or uniquing it.
//
// The change reporting is very coarse: whenever the context commits the
// query is re-run in the background and the results reported.
//
// This works fine with our 'root context is always saved' approach but
// will just go out of sync used in other contexts or if we get lazier
// about saving the root.
//

/// A type for the query the delegate is required to build
public typealias ModelFieldFetchRequest = NSFetchRequest<NSDictionary>

/// A type for the results of a field fetch request
public typealias ModelFieldResults = [[String : AnyObject]]

/// The delegate of the `ModelFieldWatcher` receives query results.
public protocol ModelFieldWatcherDelegate: class {
    /// Called on foreground queue when results of query may have changed
    func updateQueryResults(results: ModelFieldResults)
}

/// A `ModelFieldWatcher` watches the root context and refreshes the results
/// of a field-based query when necessary.
public final class ModelFieldWatcher {
    private let modelProvider: ModelProvider
    private let fetchRequest: ModelFieldFetchRequest
    private var listener: NotificationListener?

    /// Create a new `ModelFieldWatcher`.  Nothing happens until `delegate` is set.
    public init(modelProvider: ModelProvider, fetchRequest: ModelFieldFetchRequest) {
        self.modelProvider = modelProvider
        self.fetchRequest = fetchRequest
    }

    /// Set the watcher's delegate.  Setting this field causes the query to run
    /// for the first time and results to start being reported.
    public weak var delegate: ModelFieldWatcherDelegate? {
        didSet {
            if delegate != nil {
                self.listener = NotificationListener(
                    name: NSNotification.Name.NSManagedObjectContextDidSave,
                    from: [modelProvider.model.managedObjectContext],
                    callback: { [weak self] _ in self?.refresh() })
                refresh()
            }
        }
    }

    deinit {
        listener?.stopListening()
        listener = nil
    }

    private func refresh() {
        modelProvider.performBackgroundTask { model in
            let results = model.createFieldResults(fetchRequest: self.fetchRequest)
            Dispatch.toForeground {
                self.delegate?.updateQueryResults(results: results)
            }
        }
    }
}
