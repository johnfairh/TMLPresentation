//
//  ModelFieldWatcher.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

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

/// The callback of the `ModelFieldWatcher` receives query results on the foreground queue.
public typealias ModelFieldWatcherCallback = (ModelFieldResults) -> Void

/// A `ModelFieldWatcher` watches the root context and refreshes the results
/// of a field-based query when necessary.
public final class ModelFieldWatcher {
    private let bgModel: Model
    private let fetchRequest: ModelFieldFetchRequest
    private var listener: NotificationListener?

    /// Create a new `ModelFieldWatcher`.  Nothing happens until `delegate` is set.
    /// The passed-in `baseModel` is used as reference, the fetches occur on a new
    /// background-thread-context model that is forked from this base.
    init(baseModel: Model, fetchRequest: ModelFieldFetchRequest) {
        self.bgModel = baseModel.createChildModel(background: true)
        self.fetchRequest = fetchRequest
        self.listener = nil
        self.listener = baseModel.createListener(name: .NSManagedObjectContextDidSave) {
            [weak self] _ in self?.refresh()
        }
    }

    /// Set the watcher's callback.  Setting this field causes the query to run
    /// for the first time and results to start being reported.
    public var callback: ModelFieldWatcherCallback? {
        didSet {
            if callback != nil {
                refresh()
            }
        }
    }

    deinit {
        listener?.stopListening()
        listener = nil
    }

    private func refresh() {
        bgModel.perform { model in
            let results = model.createFieldResults(fetchRequest: self.fetchRequest)
            Dispatch.toForeground {
                self.callback?(results)
            }
        }
    }
}
