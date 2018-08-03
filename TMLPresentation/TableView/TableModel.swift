//
//  PresenterUI.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation
import CoreData
import UIKit

///
/// Yet Another Generic TableView - CoreData scaffold.
/// Attempt to wrap up behaviour common between all the core-data tableviews.
///
/// Fell into immense piles of poo caused by
/// 1) @objc requirement for TableView protocols; and
/// 2) Swift's interesting level of support for generic protocols.
///
/// So this is not as pretty as I'd hoped --- will revise as I find out more and as
/// language changes.
///
/// Requires just one type of model object in the table.
/// Supports multiple tablecell types in the table at once.
///

// MARK: - TableCell

///
/// Protocol to mark a cell associated with a particular model type
///
public protocol TableCell {
    associatedtype ModelType
    func configure(_ modelObject: ModelType)
}

// MARK: - TableModelDelegate

///
/// Routines to be optionally implemented to give scene-specific behaviour on a model
/// object perspective when table actions happen.
///
public protocol TableModelDelegate: class {
    associatedtype ModelType
    associatedtype SectionType

    func canDeleteObject(_ modelObject: ModelType) -> Bool
    func deleteObject(_ modelObject: ModelType)

    /// Police start of a reorder - default false
    func canMoveObject(_ modelObject: ModelType) -> Bool
    /// Police end of a reorder - default true
    func canMoveObjectTo(_ modelObject: ModelType, toSection: SectionType, toRowInSection: Int) -> Bool
    /// Actually do the move - implement one of these depending on whether you have sections
    func moveObject(_ modelObject: ModelType, fromRow: Int, toRow: Int)
    func moveObject(_ modelObject: ModelType, fromRowInSection: Int,
                    toSection: SectionType, toRowInSection: Int)
    
    /// This next is ModelObject rather than ModelType because Swift does not permit
    /// contravariant matching of arg types -- ie. we cannot fulfill this method if it
    /// said ModelType here with ModelObject, even though ModelType:ModelObject meaning
    /// the substitution is valid.  See the common UITableView subclass.
    func selectObject(_ modelObject: ModelObject)
    
    /// Only needed if table has multiple cell types.  All must be subclasses of
    /// the same TableCell-adopting class.
    func cellClassForObject(_ modelObject: ModelType) -> AnyClass?
    
    /// For notification and propagation of height changes
    func objectsChanged()

    /// Leading swipe actions
    func leadingSwipeActionsForObject(_ modelObject: ModelType) -> UISwipeActionsConfiguration?

    /// Sections decoding
    func getSectionTitle(name: String) -> String
    func getSectionObject(name: String) -> SectionType
}

/// Extension to provide safe defaults
public extension TableModelDelegate {
    func canDeleteObject(_ modelObject: ModelType) -> Bool { return false }
    func deleteObject(_ modelObject: ModelType) {}

    func canMoveObject(_ modelObject: ModelType) -> Bool { return false }
    func canMoveObjectTo(_ modelObject: ModelType, toSection: SectionType, toRowInSection: Int) -> Bool { return true }
    func moveObject(_ from: ModelType, fromRow: Int, toRow: Int) {}
    func moveObject(_ modelObject: ModelType, fromRowInSection: Int,
                    toSection: SectionType, toRowInSection: Int) {}

    func selectObject(_ modelObject: ModelObject) {}
    func cellClassForObject(_ modelObject: ModelType) -> AnyClass? { return nil }
    func objectsChanged() {}
    func leadingSwipeActionsForObject(_ modelObject: ModelType) -> UISwipeActionsConfiguration? { return nil }
    func getSectionTitle(name: String) -> String { return name }
    func getSectionObject(name: String) -> String { return name }
}

// MARK: - TableModel

///
/// Glue together a table view and a core data query and configure cells / report changes
/// based on user actions at the model level.
///
/// Note to future self: The reason that we require DelegateType here explicitly is because the
/// Delegate protocol, TableModelDelegate, has associated-type requirements meaning Swift does
/// not support it as a property type.  Instead of type-erasure gorp we require the user to provide
/// the concrete type they are using for the delegate.  Blech.  Roll on swift 5.
///
public final class TableModel<CellType, DelegateType> : NSObject,
    UITableViewDataSource,
    UITableViewDelegate,
    NSFetchedResultsControllerDelegate where
    CellType: TableCell, CellType: UITableViewCell,
    DelegateType: TableModelDelegate,
    CellType.ModelType: ModelObject,
    CellType.ModelType: NSManagedObject,
    CellType.ModelType == DelegateType.ModelType
{
    public typealias ModelType = CellType.ModelType
    
    private weak var tableView: UITableView?
    private      var fetchedResultsController: ModelResults
    private weak var delegate: DelegateType?
    private      var userMovingCells: Bool

    public init(tableView: UITableView,
                fetchedResultsController: ModelResults,
                delegate: DelegateType) {
        self.tableView = tableView
        self.fetchedResultsController = fetchedResultsController
        self.delegate = delegate
        self.userMovingCells = false
        super.init()
    }

    public func start() {
        // Bind ...
        tableView?.dataSource = self
        tableView?.delegate = self
        fetchedResultsController.delegate = self
        
        // Go!
        do {
            try fetchedResultsController.performFetch()
            tableView?.reloadData()
        } catch {
            Log.log("** Core Data fetch failed - \(error) - pressing on")
        }
    }
    
    // Instances of this class come and go, connecting to FRCs which are longer-lived when required.
    // This means we have to be very careful to break the (unowned-unsafe) FRC->Delegate (us) link.
    deinit {
        tableView?.dataSource = nil
        tableView?.delegate = nil
        fetchedResultsController.delegate = nil
    }
    
    // MARK: - Helper getters
    
    private func getModelObjectAtIndexPath(_ indexPath: IndexPath) -> ModelType {
        guard let modelObject = fetchedResultsController.object(at: indexPath) as? ModelType else {
            fatalError("Can't get expected modeltype")
        }
        return modelObject
    }
    
    private func getCellAtIndexPath(_ indexPath: IndexPath) -> CellType {
        guard let cell = tableView?.cellForRow(at: indexPath) as? CellType else {
            fatalError("Missing Cell for indexPath \(indexPath)")
        }
        return cell
    }

    private func getSectionAtIndexPath(_ indexPath: IndexPath) -> DelegateType.SectionType {
        guard let delegate = delegate, let sections = fetchedResultsController.sections else {
            Log.fatal("Can't progress, no delegate/sections")
        }
        return delegate.getSectionObject(name: sections[indexPath.section].name)
    }
    
    // MARK: - UITableViewDelegate
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.selectObject(getModelObjectAtIndexPath(indexPath))
    }
    
    // MARK: - UITableViewDataSource
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        var sectionCount = 0
        if let sections = fetchedResultsController.sections {
            sectionCount = sections.count
        }
        return sectionCount
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rows = 0
        if let sections = fetchedResultsController.sections {
            rows = sections[section].numberOfObjects
        }
        return rows
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title: String? = nil
        if let delegate = delegate, let sections = fetchedResultsController.sections {
            title = delegate.getSectionTitle(name: sections[section].name)
        }
        return title
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let modelObject = getModelObjectAtIndexPath(indexPath)
        
        var cellClass: AnyClass? = delegate?.cellClassForObject(modelObject)
        if cellClass == nil {
            cellClass = CellType.self
        }
        
        let identifier = String(describing: cellClass!)
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? CellType else {
            fatalError("Can't dequeue cell with id \(identifier)")
        }
        
        cell.configure(modelObject)
        
        return cell
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let delegate = delegate else {
            return false
        }
        let modelObject = getModelObjectAtIndexPath(indexPath)
        return delegate.canDeleteObject(modelObject) ||
               delegate.canMoveObject(modelObject)
    }

    public func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        let canDelete = delegate?.canDeleteObject(getModelObjectAtIndexPath(indexPath)) ?? false
        return canDelete ? .delete : .none
    }

    public func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return delegate?.canDeleteObject(getModelObjectAtIndexPath(indexPath)) ?? false
    }

    public func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return delegate?.leadingSwipeActionsForObject(getModelObjectAtIndexPath(indexPath))
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else {
            fatalError("Unexpected editing style")
        }

        if let delegate = delegate {
            let modelObject = getModelObjectAtIndexPath(indexPath)
            assert(delegate.canDeleteObject(modelObject))
            delegate.deleteObject(modelObject)
        }
    }
    
    // police move source - from datasource
    public func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return delegate?.canMoveObject(getModelObjectAtIndexPath(indexPath)) ?? false
    }
    
    // police move destination - from delegate (gg apple)
    public func tableView(_ tableView: UITableView,
                          targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                          toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        let object = getModelObjectAtIndexPath(sourceIndexPath)
        let proposedSection = getSectionAtIndexPath(proposedDestinationIndexPath)
        let moveOK = delegate?.canMoveObjectTo(object,
                                               toSection: proposedSection,
                                               toRowInSection: proposedDestinationIndexPath.row) ?? true
        if moveOK {
            return proposedDestinationIndexPath
        } else {
            return sourceIndexPath
        }
    }

    // do the move - from datasource
    public func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if let delegate = delegate {
            let sourceObject = getModelObjectAtIndexPath(sourceIndexPath)
            assert(!userMovingCells)
            userMovingCells = true
            delegate.moveObject(sourceObject, fromRow: sourceIndexPath.row, toRow: destinationIndexPath.row)
            delegate.moveObject(sourceObject,
                                fromRowInSection: sourceIndexPath.row,
                                toSection: getSectionAtIndexPath(destinationIndexPath),
                                toRowInSection: destinationIndexPath.row)
            userMovingCells = false
        }
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    // Seeing problems with the NSFRC API when sections are used.  Eg. just one item in the query
    // and it changes from section A to section B.  Core Data issues 'delete section 0',
    // 'insert section 0', 'refresh object (0,0,)'.  This is wrong according to tableview's batch
    // processing rules (it turns it into (1,0) because of the 'insert section').
    //
    // So we take advantage of Core Data sending all section updates before object updates and only
    // do the batch update when there are no section updates.  If there are section updates -- rare --
    // then we do no batch stuff and reload the entire table when core data is finished.
    //
    // What a mess.
    //
    // UPDATE 17th October.  Further mess.  If we have a one-entry view (ie section 0 key 0) and
    // then delete it from the UI, core data sends us the item delete before the section delete.
    // So, the above strat fails.  Giving up on solving this for now, instead we will just skip
    // any kind of incremental update if the table has sections.
    //
    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView?.beginUpdates()
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                           didChange sectionInfo: NSFetchedResultsSectionInfo,
                           atSectionIndex sectionIndex: Int,
                           for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            Log.debugLog("**** TableModel.section(insert) \(sectionIndex)")
            tableView?.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            Log.debugLog("**** TableModel.section(delete) \(sectionIndex)")
            tableView?.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default:
            Log.fatal("TableModel.section(??) Not sure what to do with \(type.rawValue)")
        }
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {
        // Debug tracing, woe is me
        switch type {
        case .delete:
            Log.debugLog("**** TableModel.row(delete) \(indexPath!)")
        case .move:
            Log.debugLog("**** TableModel.row(move) \(indexPath!) to \(newIndexPath!)")
        case .update:
            Log.debugLog("**** TableModel.row(update) \(indexPath!)")
        case .insert:
            Log.debugLog("**** TableModel.row(insert) \(newIndexPath!)")
        }

        // Bail immediately if the events are driven by user direct manipulation, in which
        // case the UI has already been updated by UITableView and we can only make things
        // look ugly or wrong.
        //
        // Bail immediately if the table has sections because I am too dumb to mediate between
        // core data and ui kit.
        //
        guard !userMovingCells else {
            return
        }
        
        switch type {
        case .delete:
            tableView?.deleteRows(at: [indexPath!], with: .fade)
        case .move:
            // assume a change (to sort field) also, no separate .Update
            tableView?.deleteRows(at: [indexPath!], with: .fade)
            tableView?.insertRows(at: [newIndexPath!], with: .fade)
        case .update:
            /// Fun times.
            /// The standard boilerplate suggests redrawing the cell here.  In fact this gets
            /// messed up when the update happens as part of a set of changes triggered eg.
            /// by a delete and all the rows get smushed about.
            /// Rather than manually reordering the updates, this seems to work without bad
            /// side effects....
            tableView?.reloadRows(at: [indexPath!], with: .automatic)
        case .insert:
            tableView?.insertRows(at: [newIndexPath!], with: .fade)
        }
    }
    
    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView?.endUpdates()
        delegate?.objectsChanged()
    }
}
