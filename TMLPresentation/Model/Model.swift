//
//  Model.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation
import CoreData

///
/// Database (core-data)-related services available to application logic
/// and ModelObject layer
///
public protocol Model {

    // MARK: - ModelObject services
    
    /// Create a new instance of a ModelObject
    func create(_ entityName: String) -> NSManagedObject
    
    /// Delete an object.  Save to commit.
    func delete(_ object: NSManagedObject)
    
    /// Check an object still exists.
    func objectExists(_ object: NSManagedObject) -> Bool
    
    /// Translate an object from another ModelServices instance to this one
    func convertFromOtherModel(_ object: NSManagedObject) -> NSManagedObject
    
    /// Get the next sort order value for a particular MO + sort key
    func getNextSortOrderValue(_ entityName: String, keyName: String) -> Int64

    // MARK: - Bespoke queries

    /// Find an object by name
    func find(_ entityName: String, name: String) -> NSManagedObject?
    
    /// Find the 'first' object under some query+sort
    func findFirst(sortDescriptor: NSSortDescriptor, fetchReqName: String) -> NSManagedObject?

    /// Find the 'first' object under some predicate + sort
    func findFirst(entityName: String, predicate: NSPredicate, sortedBy: [NSSortDescriptor]) -> NSManagedObject?

    // MARK: - General queries

    /// Count the number of objects that would be returned by a findAll
    func count(fetchReqName reqName:String, substitutionVariables vars: [String:AnyObject]) -> Int

    /// Count the number of objects that would be returned by a findAll
    func count(entityName: String, predicate: NSPredicate?) -> Int

    /// Find all objects in a given query - static array returned, not updated subsequently
    func findAll(fetchReqName reqName: String,
                 sortedBy: [NSSortDescriptor],
                 substitutionVariables vars: [String:AnyObject]) -> [NSManagedObject]

    /// Find all objects matching a predicate, sorted.  Static array returned.
    func findAll(entityName: String,
                 predicate: NSPredicate?,
                 sortedBy: [NSSortDescriptor]) -> [NSManagedObject]

    /// Set up a live query ready to run, using predicates from the model
    func createFetchedResults(fetchReqName reqName: String,
                              sortedBy: [NSSortDescriptor],
                              substitutionVariables vars: [String:AnyObject],
                              sectionNameKeyPath: String?) -> ModelResults


    /// Set up a live query ready to run, using a given predicate
    func createFetchedResults(entityName: String,
                              predicate: NSPredicate?,
                              sortedBy: [NSSortDescriptor],
                              sectionNameKeyPath: String?) -> ModelResults

    /// Run a fetch for field data
    func createFieldResults(fetchRequest: ModelFieldFetchRequest) -> ModelFieldResults

    /// Set up a live object that notifies when the fields change
    func createFieldWatcher(fetchRequest: ModelFieldFetchRequest) -> ModelFieldWatcher

    /// Clone a fetched-results-controller but with a different predicate
    func cloneResults(_ results: ModelResults, withPredicate predicate: NSPredicate) -> ModelResults
    
    // MARK: - Model services
    
    /// Request a save of changes to the database.  Executes asynchronously.
    func save(_ done: @escaping () -> Void)

    /// Request a save of changes to the database.  Blocks.
    func saveAndWait()
    
    /// Obtain a temporary child model workspace
    func createChildModel(background: Bool) -> Model

    /// Run code asynchronously on the Model's queue
    func perform(action: @escaping (Model) -> Void)

    // MARK: - Notifications
    func createListener(name: NSNotification.Name, callback: @escaping NotificationListener.Callback) -> NotificationListener
}

///
/// Extension to provide default arguments to certain methods
///
extension Model {
    
    public func createFetchedResults(fetchReqName reqName: String,
                                     sortedBy: [NSSortDescriptor],
                                     substitutionVariables vars: [String:AnyObject] = [:]) -> ModelResults {
        return createFetchedResults(fetchReqName: reqName, sortedBy: sortedBy, substitutionVariables: vars, sectionNameKeyPath: nil)
    }

    public func findAll(fetchReqName reqName: String, sortedBy: [NSSortDescriptor]) -> [NSManagedObject] {
        return findAll(fetchReqName: reqName, sortedBy: sortedBy, substitutionVariables: [:])
    }
    
    public func count(fetchReqName reqName: String) -> Int {
        return count(fetchReqName: reqName, substitutionVariables: [:])
    }

    public func count(entityName: String) -> Int {
        return count(entityName: entityName, predicate: nil)
    }
    
    public func save() {
        save {}
    }

    public func createChildModel() -> Model {
        return createChildModel(background: false)
    }
}
