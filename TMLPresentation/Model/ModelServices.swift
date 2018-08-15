//
//  ModelServices.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.

import Foundation
import CoreData

///
/// Main implementation of the Model protocol, providing error handling and support
/// for management of child models on top of an NSManagedObjectContext
///
open class ModelServices: Model {
    private let managedObjectModel:   NSManagedObjectModel
    public  let managedObjectContext: NSManagedObjectContext
    private var parentModel:          ModelServices?
    
    private var isRoot: Bool { return parentModel == nil }
    
    public init(managedObjectModel: NSManagedObjectModel, managedObjectContext: NSManagedObjectContext) {
        self.managedObjectModel   = managedObjectModel
        self.managedObjectContext = managedObjectContext
        self.parentModel          = nil
    }
    
    private convenience init(parentModel: ModelServices, background: Bool) {
        let newMoc = NSManagedObjectContext(concurrencyType: background ? .privateQueueConcurrencyType : .mainQueueConcurrencyType)
        newMoc.parent = parentModel.managedObjectContext
        
        self.init(managedObjectModel: parentModel.managedObjectModel, managedObjectContext: newMoc)
        self.parentModel = parentModel
    }
    
    // MARK: - FetchRequest helpers
    
    /// Helper to load + configure a request from the model
    private func loadFetchRequest(_ fetchReqName: String,
                                  sortedBy: [NSSortDescriptor],
                                  substitutionVariables vars: [String:AnyObject] = [:]) -> NSFetchRequest<NSManagedObject> {
        // ok so because we want to put a sort on, and we can't put a sort on in the MOM version,
        // we have to use ...fromTemplateWithName... because otherwise it crashes.
        guard let fetchReq = managedObjectModel.fetchRequestFromTemplate(withName: fetchReqName,
                                                                         substitutionVariables: vars) else {
            Log.fatal("Can't load fetch request \(fetchReqName) from model")
        }
        fetchReq.sortDescriptors = sortedBy
        return fetchReq as! NSFetchRequest<NSManagedObject>
    }

    /// Helper to manually create a fetchrequest
    func createFetchReq(entityName: String, predicate: NSPredicate?, sortedBy: [NSSortDescriptor]) -> NSFetchRequest<NSManagedObject> {
        let fetchReq = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchReq.predicate = predicate
        fetchReq.sortDescriptors = sortedBy
        return fetchReq
    }
    
    /// Helper to issue a request expecting one (or zero) object
    private func issueSingularFetchRequest(fetchReq: NSFetchRequest<NSManagedObject>) -> NSManagedObject? {
        fetchReq.fetchLimit = 1
        var result: NSManagedObject? = nil
        do {
            let results = try managedObjectContext.fetch(fetchReq)
            if results.count > 0 {
                result = results[0]
            }
        } catch {
            Log.log("**** Model: Fetch request for 'any' \(fetchReq.entityName!)' failed, \(error)")
        }
        return result
    }

    /// Helper to issue a fetch request for fields
    public func createFieldResults(fetchRequest: ModelFieldFetchRequest) -> ModelFieldResults {
        do {
            let rawResults = try managedObjectContext.fetch(fetchRequest)
            guard let fieldResults = rawResults as? [[String : AnyObject]] else {
                Log.fatal("Bad type coming back from core data - \(rawResults)")
            }
            return fieldResults
        } catch {
            Log.log("Model fetchReq failed: \(error) - returning no results found")
        }
        return []
    }

    public func createFieldWatcher(fetchRequest: ModelFieldFetchRequest) -> ModelFieldWatcher {
        return ModelFieldWatcher(baseModel: self, fetchRequest: fetchRequest)
    }
    
    // MARK: - Simple object routines
    
    /// Create a new instance of a ModelObject
    public func create(_ entityName: String) -> NSManagedObject {
        return NSEntityDescription.insertNewObject(forEntityName: entityName,
                                                   into: managedObjectContext)
    }
    
    /// Delete an object.  Save to commit.
    public func delete(_ object: NSManagedObject) {
        managedObjectContext.delete(object)
    }
    
    /// Check an object still exists (deleted from context during user tab-switch etc.)
    public func objectExists(_ object: NSManagedObject) -> Bool {
        do {
            let id = object.objectID
            try  _ = managedObjectContext.existingObject(with: id)
            return true
        } catch {
            Log.log("Object \(object) does not exist, \(error)")
        }
        return false
    }
    
    /// Translate an object from another ModelServices instance to this one
    public func convertFromOtherModel(_ object: NSManagedObject) -> NSManagedObject {
        return managedObjectContext.object(with: object.objectID)
    }
    
    /// Get the next sort order value for a particular MO + sort key
    ///
    /// MOs with a user-defined sort order use an Int64 field for the sort key.
    /// When creating a new object, we have to assign a unique value.
    /// Do this by finding the current maximum and adding 1.  Do this using
    /// a sorted query rather than a 'max' because we must include pending changes
    /// which is not supported by dictionaryResultType.
    ///
    public func getNextSortOrderValue(_ entityName: String, keyName: String) -> Int64 {
        let sortDescriptor = NSSortDescriptor(key: keyName, ascending: false)
        
        let fetchReq = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchReq.sortDescriptors        = [sortDescriptor]
        fetchReq.returnsObjectsAsFaults = false
        assert(fetchReq.includesPendingChanges)
        
        guard let result = issueSingularFetchRequest(fetchReq: fetchReq) else {
            // no objects - sort order 0
            return 0
        }
        
        guard let maxSortOrderValue = result.value(forKey: keyName) as? NSNumber else {
            Log.fatal("Unexpected type for \(keyName)")
        }
        
        let nextSortOrderValue = maxSortOrderValue.int64Value + 1
        
        Log.log("Model: getNextSortOrderValue for \(entityName) using \(keyName) is \(nextSortOrderValue)")
        
        return nextSortOrderValue
    }

    // MARK: - Finding and counting
    
    /// Find an object by name
    public func find(_ entityName: String, name: String) -> NSManagedObject? {
        let fetchReq = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchReq.predicate = NSPredicate(format: "name == %@", argumentArray: [name])
        return issueSingularFetchRequest(fetchReq: fetchReq)
    }
    
    /// Find the 'first' object under some query+sort
    public func findFirst(sortDescriptor: NSSortDescriptor, fetchReqName: String) -> NSManagedObject? {
        let fetchReq = loadFetchRequest(fetchReqName, sortedBy: [sortDescriptor])
        return issueSingularFetchRequest(fetchReq: fetchReq)
    }

    /// Find the 'first' object under some predicate + sort
    public func findFirst(entityName: String, predicate: NSPredicate, sortedBy: [NSSortDescriptor]) -> NSManagedObject? {
        let fetchReq = createFetchReq(entityName: entityName, predicate: predicate, sortedBy: sortedBy)
        return issueSingularFetchRequest(fetchReq: fetchReq)
    }
    
    /// Count the number of objects that would be returned by a findAll
    public func count(fetchReqName reqName:String, substitutionVariables vars: [String:AnyObject]) -> Int {
        // Grab fetchreq from model + tweak
        let fetchReq = loadFetchRequest(reqName, sortedBy: [], substitutionVariables: vars)
        fetchReq.resultType = .countResultType
        
        do {
            return try managedObjectContext.count(for: fetchReq)
        } catch {
            Log.fatal("Can't count \(reqName) - \(error)")
        }
    }
    
    /// Find all objects in a given query - static array returned, not updated subsequently
    public func findAll(fetchReqName reqName: String,
                        sortedBy: [NSSortDescriptor],
                        substitutionVariables vars: [String:AnyObject]) -> [NSManagedObject] {
        let fetchReq = loadFetchRequest(reqName, sortedBy: sortedBy, substitutionVariables: vars)
        do {
            return try managedObjectContext.fetch(fetchReq)
        } catch {
            Log.log("**** Model: Fetch request for \(reqName) failed, \(error)")
        }
        return []
    }
    
    
    /// Set up a live query ready to run, using a template in the data model
    public func createFetchedResults(fetchReqName reqName: String,
                                     sortedBy: [NSSortDescriptor],
                                     substitutionVariables vars: [String:AnyObject],
                                     sectionNameKeyPath: String?) -> ModelResults {
        let fetchReq = loadFetchRequest(reqName, sortedBy: sortedBy, substitutionVariables: vars)
        return NSFetchedResultsController(fetchRequest: fetchReq,
                                          managedObjectContext: managedObjectContext,
                                          sectionNameKeyPath: sectionNameKeyPath,
                                          cacheName: nil)
    }

    /// Set up a live query ready to run, using a given predicate
    public func createFetchedResults(entityName: String,
                                     predicate: NSPredicate?,
                                     sortedBy: [NSSortDescriptor] ,
                                     sectionNameKeyPath: String?) -> ModelResults {
        let fetchReq = createFetchReq(entityName: entityName,
                                      predicate: predicate,
                                      sortedBy: sortedBy)
        return NSFetchedResultsController(fetchRequest: fetchReq,
                                          managedObjectContext: managedObjectContext,
                                          sectionNameKeyPath: sectionNameKeyPath,
                                          cacheName: nil)
    }

    /// Clone a fetched-results-controller but with a different predicate
    public func cloneResults(_ results: ModelResults, withPredicate predicate: NSPredicate) -> ModelResults {
        guard let entityName = results.fetchRequest.entityName else {
            Log.fatal("Missing entity name")
        }
        let newFetchReq = NSFetchRequest<NSManagedObject>(entityName: entityName)
        newFetchReq.predicate = predicate
        newFetchReq.sortDescriptors = results.fetchRequest.sortDescriptors
        // TODO: should really copy all the other settings...
        return NSFetchedResultsController(fetchRequest: newFetchReq,
                                          managedObjectContext: managedObjectContext,
                                          sectionNameKeyPath: nil,
                                          cacheName: nil)
    }
    
    // MARK: - Save

    /// Saving then.
    /// Edits in the main context are things like:
    /// 1) Table re-orders
    /// 2) Edits that occur in 'view' screens, ie. no 'undo', like Item notes
    ///    and goal updates.
    /// The views managing these are obliged to save the (root) model when they
    /// are done.
    ///
    /// When we start a 'create' view or start 'edit' session in Director, the view
    /// gets a new child Model (MOC) that they work in.  If they cancel, this child MOC
    /// is thrown away and changes are ignored.  If they accept, they call 'save' on the
    /// child Model to push changes back to the parent.
    /// AT THIS POINT WE MUST ALWAYS ALSO SAVE THE PARENT (ROOT) MODEL.
    ///
    /// A 'create' view (with child Model) may themselves request a further 'create' view.
    /// This is important to support definition of a goal hierarchy in a top-down natural
    /// way.
    /// In this case, the new view gets its new child Model (so it can cancel edits without
    /// messing up its parent (the intermediate child) and so on until we run out of memory.
    /// When such a child saves, ie. the user finishes entering their subgoal, the user is
    /// then left looking at the 'create' view for their 'top' goal.
    /// AT THIS POINT WE MUST NOT ALSO SAVE ANY OTHER MODELS.
    ///
    /// So the rule is:
    /// If I finish saving, and I notice I have a parent Model, and the parent Model is the
    /// root model, go save it too.
    
    /// helper to actually do a save, as a callback to some passed-in function
    func doSave(asCallbackTo: (@escaping ()->())->(), done: @escaping ()->Void) {
        asCallbackTo {
            do {
                try self.managedObjectContext.save()
                if !self.isRoot {
                    Log.log("Model: model saved OK")
                    guard let parent = self.parentModel else {
                        Log.fatal("Not root but no parent??")
                    }
                    if parent.isRoot {
                        Log.log("Model: model is not root and parent is, requesting parent save")
                        parent.save(done)
                    } else {
                        Log.log("Model: model is not root and neither is parent, no more saves")
                        done()
                    }
                } else {
                    Log.log("Model: root model saved OK")
                    done()
                }
            } catch {
                if Log.crashWhenPossible {
                    Log.fatal("moc.save failed - not pressing on. \(error)")
                } else {
                    Log.log("**** Model: moc.save failed.  Pressing on regardless. \(error)")
                    done()
                }
            }
        }
    }
    
    /// Request a save of changes to the database.  Executes asynchronously, client can care or not.
    public func save(_ done: @escaping ()->() = {}) {
        doSave(asCallbackTo: managedObjectContext.perform, done: done)
    }
    
    /// Request a sync save of changes to the DB.  Root context only.
    public func saveAndWait() {
        Log.assert(isRoot, message: "Only OK for root context")
        doSave(asCallbackTo: managedObjectContext.performAndWait, done: {})
    }

    // MARK: Misc
    
    /// Obtain a temporary child model workspace
    public func createChildModel(background: Bool) -> Model {
        return ModelServices(parentModel: self, background: background)
    }

    /// Run something on the model's queue
    public func perform(action: @escaping (Model) -> Void) {
        managedObjectContext.perform {
            action(self)
        }
    }

    /// Create a notification listener, set up in listening state.
    public func createListener(name: NSNotification.Name,
                               callback: @escaping NotificationListener.Callback) -> NotificationListener {
        return NotificationListener(name: name, from: managedObjectContext, callback: callback)
    }
}
