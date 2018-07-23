//
//  ModelProvider.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation
import CoreData

/// Create the core data container and vend model services for the root model
///
public final class ModelProvider {
    // Configuration
    private let userDbName: String

    // Core data stack
    private var persistentContainer: NSPersistentContainer
    public private(set) var model: Model!

    // Initialization callback
    private var readyCallback: (() -> Void)?

    /// Initializer to use an existing persistent container.
    public init(persistentContainer: NSPersistentContainer, userDbName: String) {
        self.userDbName = userDbName
        self.persistentContainer = persistentContainer
    }

    /// Initializer to create the root model on the main queue.  Model is not usable until
    /// 'load' is called later on
    public init(userDbName: String) {
        self.userDbName = userDbName
        self.persistentContainer = NSPersistentContainer(name: userDbName)
    }

    /// Start creating a new core data stack during App.didLoad, quickly go async.
    /// Call back onto main thread when done.
    public func load(createFreshStore: Bool, _ readyCallback: @escaping ()->Void) {
        self.readyCallback = readyCallback

        // Trace DB location and version
        let directoryURL = type(of: persistentContainer).defaultDirectoryURL()
        let dbURL        = directoryURL.appendingPathComponent("\(userDbName).sqlite")
        let momVersion   = persistentContainer.managedObjectModel.versionIdentifiers.first

        Log.log("Using mom \(momVersion!), database file " + dbURL.absoluteString )

        // Debug setting to delete any prior store
        if createFreshStore {
            do {
                Log.log("Init: ModelProvider: debugCreateFreshStore is set: simulating first-run")
                try persistentContainer.persistentStoreCoordinator.destroyPersistentStore(
                    at: dbURL, ofType: NSSQLiteStoreType, options: nil)
            } catch {
                Log.fatal("Error deleting the old store: \(error)")
            }
        }

        Log.log("Init: ModelProvider: requesting background work")

        persistentContainer.persistentStoreDescriptions[0].shouldAddStoreAsynchronously = true
        persistentContainer.loadPersistentStores(completionHandler: modelDidInitialize)
    }

    /// Callback when model is up and DB loaded
    private func modelDidInitialize(psDescription: NSPersistentStoreDescription, error: Error?) {
        Log.log("Init: ModelProvider: back to foreground")
        Log.assert(psDescription.shouldMigrateStoreAutomatically)
        Log.assert(psDescription.shouldInferMappingModelAutomatically)

        if let error = error {
            Log.fatal("Error loading DB: \(error)")
        }

        model = ModelServices(managedObjectModel: persistentContainer.managedObjectModel,
                              managedObjectContext: persistentContainer.viewContext)

        self.readyCallback?()
        self.readyCallback = nil
    }

    /// Helper to execute a background task
    public func performBackgroundTask(task: @escaping (Model) -> () ) {
        persistentContainer.performBackgroundTask { [weak self] context in
            guard let managedObjectModel = self?.persistentContainer.managedObjectModel else {
                Log.log("Confused by lack of things in background context, bailing")
                return
            }

            let model = AsyncModelServices(managedObjectModel: managedObjectModel,
                                           managedObjectContext: context)
            task(model)
        }
    }
}

/// Slight variant of model services designed to run in a background task.
/// In particular must not go async to save because we are already in the context....
fileprivate class AsyncModelServices: ModelServices {

    /// Request a save of changes to the database.  Executes asynchronously, client can care or not.
    override func save(_ done: @escaping ()->()) {
        doSave(asCallbackTo: {x in x()}, done: done)
    }

    /// Request a sync save of changes to the DB.  Root context only.
    override func saveAndWait() {
        save()
    }
}
