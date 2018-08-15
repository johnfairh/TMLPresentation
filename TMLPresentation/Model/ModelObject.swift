//
//  Model.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import CoreData

/// Protocol to hold common behaviour between various managed object classes.
/// Provide type-safe APIs that work with the Model controller.
///
/// Adopter classes must
/// 1) Inherit from NSManagedObject
/// 2) Have the same class name as the Core Data entity that they are managing
///
public protocol ModelObject {
    /// Create a new instance inserted into the model
    static func create(from model: Model) -> Self
    
    /// Get hold of an object in a given model from a version in another!
    func convert(_ to: Model) -> Self
    
    /// Look up an existing instance in the model
    static func find(from model: Model, named: String) -> Self?
    
    /// Look up the 'first' instance - using the default sort order
    static func findFirst(from model: Model, fetchReqName: String) -> Self?

    /// Look up the 'first' instance under some predicate
    static func findFirst(model: Model,
                          predicate: NSPredicate,
                          sortedBy: [NSSortDescriptor]) -> Self?

    /// Delete from the model
    func delete(from model: Model)

    /// Does the object still exist?
    func stillExists(in model: Model) -> Bool
    
    /// Give a default sort descriptor.  Used for the default query and 'findFirst'
    static var defaultSortDescriptor : NSSortDescriptor { get }
    
    /// Get the value for a given SortOrder for this instance
    func getSortOrder(_ sortOrder: ModelSortOrder) -> Int64

    /// Set the value for a given SortOrder for this instance
    func setSortOrder(_ sortOrder: ModelSortOrder, newValue: Int64)

    /// Get the next free value for given SortOrder for this instance
    static func getNextSortOrderValue(_ sortOrder: ModelSortOrder, from model: Model) -> Int64
}

/// A ModelSortOrder is the name of an Int64 property that is used to sort an entity.
/// Entities can have several such sortorders.
public struct ModelSortOrder {
    public let keyName: String
    public let ascending: Bool
    
    public init(keyName: String, ascending: Bool = true) {
        self.keyName = keyName
        self.ascending = ascending
    }
}

/// This extension provides a full implementation of the majority of the ModelObject protocol,
/// linking between the Model core data stack and the type-correct model objects.
///
/// The parts remaining un-implemented are:
///   defaultSortDescriptor
///
extension ModelObject where Self: NSManagedObject {
    private static var entityName: String {
        return String(describing: self)
    }
    
    public static func create(from model: Model) -> Self {
        return model.create(entityName) as! Self
    }
    
    public func convert(_ to: Model) -> Self {
        return to.convertFromOtherModel(self) as! Self
    }
    
    public static func find(from model:Model, named:String) -> Self? {
        return model.find(entityName, name: named) as? Self
    }
    
    public static func findFirst(from model: Model, fetchReqName: String) -> Self? {
        return model.findFirst(sortDescriptor: defaultSortDescriptor, fetchReqName: fetchReqName) as? Self
    }

    public static func findFirst(model: Model,
                                 predicate: NSPredicate,
                                 sortedBy: [NSSortDescriptor] = [defaultSortDescriptor]) -> Self? {
        return model.findFirst(entityName: entityName,
                               predicate: predicate,
                               sortedBy: sortedBy) as? Self
    }
    
    public func delete(from model:Model) {
        model.delete(self)
    }
    
    public func stillExists(in model: Model) -> Bool {
        return model.objectExists(self)
    }

    /// Set up a live query ready to run, using a given predicate
    public static func createFetchedResults(model: Model,
                                            predicate: NSPredicate? = nil,
                                            sortedBy: [NSSortDescriptor] = [defaultSortDescriptor],
                                            sectionNameKeyPath: String? = nil) -> ModelResults {
        return model.createFetchedResults(entityName: entityName,
                                          predicate: predicate,
                                          sortedBy: sortedBy,
                                          sectionNameKeyPath: sectionNameKeyPath)
    }

    /// Default query for the object: no predicate, default sort order
    public static func createAllResults(model: Model) -> ModelResults {
        return createFetchedResults(model: model)
    }

    /// Helper to query all wrapped in a `ModelResultsSet`
    public static func createAllResultsSet(model: Model) -> ModelResultsSet {
        return createAllResults(model: model).asModelResultsSet
    }

    /// Helper to build a `ModelFieldFetchRequest` for use with `ModelFieldWatcher`
    public static func createFieldFetchRequest(predicate: NSPredicate? = nil,
                                               sortedBy: [NSSortDescriptor] = [defaultSortDescriptor],
                                               fields: [Any],
                                               unique: Bool = false) -> ModelFieldFetchRequest {
        let fetchReq = ModelFieldFetchRequest(entityName: entityName)
        fetchReq.sortDescriptors = [defaultSortDescriptor]
        fetchReq.resultType = .dictionaryResultType
        fetchReq.propertiesToFetch = fields
        fetchReq.returnsDistinctResults = unique
        return fetchReq
    }

    // MARK: - Sort Orders
    
    public func getSortOrder(_ sortOrder: ModelSortOrder) -> Int64 {
        let moSelf = self as NSManagedObject
        guard let order = moSelf.value(forKey: sortOrder.keyName) as? NSNumber else {
            fatalError("Unexpected type for \(sortOrder.keyName)")
        }
        return order.int64Value
    }
    
    public func setSortOrder(_ sortOrder: ModelSortOrder, newValue: Int64) {
        let currValue = getSortOrder(sortOrder)
        if currValue != newValue {
            let val = NSNumber(value: newValue as Int64)
            let moSelf = self as NSManagedObject
            moSelf.setValue(val, forKey: sortOrder.keyName)
        }
    }

    public static func getNextSortOrderValue(_ sortOrder: ModelSortOrder, from model: Model) -> Int64 {
        return model.getNextSortOrderValue(entityName, keyName: sortOrder.keyName)
    }
}
