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

/// Structure to describe a leading-edge swipe action
public struct TableSwipeAction {
    public let text: String
    public let colorName: String?
    public let action: () -> Void

    public init(text: String, colorName: String? = nil, action: @escaping () -> Void) {
        self.text = text
        self.colorName = colorName
        self.action = action
    }
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
    func moveObject(_ modelObject: ModelType,
                    fromRowInSection: Int,
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
    func leadingSwipeActionsForObject(_ modelObject: ModelType) -> TableSwipeAction?

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
    func moveObject(_ modelObject: ModelType,
                    fromRowInSection: Int,
                    toSection: SectionType, toRowInSection: Int) {}

    func selectObject(_ modelObject: ModelObject) {}
    func cellClassForObject(_ modelObject: ModelType) -> AnyClass? { return nil }
    func objectsChanged() {}
    func leadingSwipeActionsForObject(_ modelObject: ModelType) -> TableSwipeAction? { return nil }
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
    UITableViewDragDelegate,
    UITableViewDropDelegate,
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
        tableView?.dragDelegate = self
        tableView?.dropDelegate = self
        tableView?.dragInteractionEnabled = true
        fetchedResultsController.delegate = self
        
        // Go!
        do {
            try fetchedResultsController.performFetch()
            tableView?.reloadData()
        } catch {
            Log.log("Core Data fetch failed - \(error) - pressing on")
        }
    }
    
    // Instances of this class come and go, connecting to FRCs which are longer-lived when required.
    // This means we have to be very careful to break the (unowned-unsafe) FRC->Delegate (us) link.
    deinit {
        tableView?.dataSource = nil
        tableView?.delegate = nil
        tableView?.dragDelegate = nil
        tableView?.dropDelegate = nil
        fetchedResultsController.delegate = nil
    }
    
    // MARK: - Helper getters
    
    private func getModelObjectAtIndexPath(_ indexPath: IndexPath) -> ModelType {
        guard let modelObject = fetchedResultsController.object(at: indexPath) as? ModelType else {
            Log.fatal("Can't get expected modeltype")
        }
        return modelObject
    }
    
    private func getCellAtIndexPath(_ indexPath: IndexPath) -> CellType {
        guard let cell = tableView?.cellForRow(at: indexPath) as? CellType else {
            Log.fatal("Missing Cell for indexPath \(indexPath)")
        }
        return cell
    }

    private func getSectionAtIndexPath(_ indexPath: IndexPath) -> DelegateType.SectionType {
        guard let delegate = delegate, let sections = fetchedResultsController.sections else {
            Log.fatal("Can't progress, no delegate/sections")
        }
        return delegate.getSectionObject(name: sections[indexPath.section].name)
    }
    
    // MARK: - Table Structure
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        var sectionCount = 0
        if let sections = fetchedResultsController.sections {
            sectionCount = sections.count
        }
        Log.tableLog("numberOfSections = \(sectionCount)")
        return sectionCount
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rows = 0
        if let sections = fetchedResultsController.sections {
            rows = sections[section].numberOfObjects
        }
        Log.tableLog("numberOfRowsInSection \(section) = \(rows)")
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
            Log.fatal("Can't dequeue cell with id \(identifier)")
        }
        
        cell.configure(modelObject)
        
        return cell
    }

    public func refreshCell(indexPath: IndexPath) {
        let modelObject = getModelObjectAtIndexPath(indexPath)
        let cell = getCellAtIndexPath(indexPath)
        cell.configure(modelObject)
    }

    // MARK: - Edit/Delete

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

    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else {
            Log.fatal("Unexpected editing style")
        }

        if let delegate = delegate {
            let modelObject = getModelObjectAtIndexPath(indexPath)
            Log.assert(delegate.canDeleteObject(modelObject))
            delegate.deleteObject(modelObject)
        }
    }

    // MARK: - Row Actions

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.selectObject(getModelObjectAtIndexPath(indexPath))
    }

    public func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let action = delegate?.leadingSwipeActionsForObject(getModelObjectAtIndexPath(indexPath)) else {
            return nil
        }
        let uiAction = UIContextualAction(style: .normal, title: action.text) { _, _, continuation in
            action.action()
            continuation(true)
        }
        if let colorName = action.colorName {
            uiAction.backgroundColor = UIColor(named: colorName) ?? .green
        }
        return UISwipeActionsConfiguration(actions: [uiAction])
    }

    // MARK: - Move

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

        return moveOK ? proposedDestinationIndexPath : sourceIndexPath
    }

    // do the move - from datasource
    public func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath != destinationIndexPath else {
            Log.tableLog("Ignoring move, src == dest (\(sourceIndexPath))")
            return
        }
        if let delegate = delegate {
            let sourceObject = getModelObjectAtIndexPath(sourceIndexPath)
            Log.assert(!userMovingCells)
            userMovingCells = true
            delegate.moveObject(sourceObject, fromRow: sourceIndexPath.row, toRow: destinationIndexPath.row)
            delegate.moveObject(sourceObject,
                                fromRowInSection: sourceIndexPath.row,
                                toSection: getSectionAtIndexPath(destinationIndexPath),
                                toRowInSection: destinationIndexPath.row)
            userMovingCells = false
            if sourceIndexPath.section != destinationIndexPath.section {
                Dispatch.toForeground {
                    self.refreshCell(indexPath: destinationIndexPath)
                }
            }
        }
    }

    // MARK: - UITableViewDragDelegate

    public func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard self.tableView(tableView, canMoveRowAt: indexPath) else {
            return []
        }

        // Workaround.
        //
        // Use drag + drop to move the last row in a section causes the section itself to delete
        // as part of the 'move' call.
        //
        // Option 1 - do the deleteSection() as part of the `move` stackframes.
        //     This appears to work if the dest IndexPath is still valid after
        //     the section has been deleted -- eg. 3 sections, move (0,0) -> (1,0).
        //
        //     BUT future drags do not work: `dropSessionDidUpdate` is never called.
        //     AND if the deleted section causes the dest IndexPath NOT to be valid
        //     (eg. move (0,0) -> (2,0)) then we get NSInternalInconsistencyException
        //
        // Option 2 - do the deleteSection() in a fibre break after the `move` stackframe.
        //     This is the requirement for the "old way" of edit move / reorder control
        //     which appears to work fine.
        //
        //     This crashes immediately the move is done (before the fibre can run) complaining
        //     that there are three (for eg.) sections in the table UI but the data model
        //     says there are only two.
        //
        // So, we forbid drag + drop from ever emptying a section.
        //
        // This doesn't actually stop the drag, good grief, but because we leave `localObject`
        // `nil` we never accept the drop.  Lordy me.
        guard let sections = fetchedResultsController.sections,
            sections[indexPath.section].numberOfObjects > 1 else {
                return []
        }

        let item = UIDragItem(itemProvider: NSItemProvider())
        item.localObject = indexPath
        return [item]
    }

    // let's not get other people involved in our mess...
    public func tableView(_ tableView: UITableView, dragSessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool {
        return true
    }

    // MARK: - UITableViewDropDelegate

    public func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return true
    }

    public func tableView(_ tableView: UITableView,
                          dropSessionDidUpdate session: UIDropSession,
                          withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {

        guard let destPath = destinationIndexPath,
            let sourceItem = session.localDragSession?.items[0],
            let sourcePath = sourceItem.localObject as? IndexPath,
            destPath == self.tableView(tableView,
                                       targetIndexPathForMoveFromRowAt: sourcePath,
                                       toProposedIndexPath: destPath) else {
                Log.tableLog("Can't drop it here => forbidden")
                return UITableViewDropProposal(operation: .forbidden)
        }

        return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    public func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        // We never get here, more's the pity, because UITableView decides to invoke `moveRow`.
        Log.fatal("performDropWith() -- what to do?")
    }

    // MARK: - NSFetchedResultsControllerDelegate
    
    // iOS 12 -- touch wood but all the NSFRC vs. sectionated UITableView issues appear to
    // be fixed!  All workarounds removed now.
    //
    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        Log.tableLog("FRCD - .controllerWillChangeContent - userMovingCells = \(userMovingCells)")
        if !userMovingCells {
            tableView?.beginUpdates()
        }
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                           didChange sectionInfo: NSFetchedResultsSectionInfo,
                           atSectionIndex sectionIndex: Int,
                           for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            Log.tableLog("FRCD - .section(insert) \(sectionIndex)")
            if !userMovingCells {
                tableView?.insertSections(IndexSet(integer: sectionIndex), with: .fade)
            }
        case .delete:
            Log.tableLog("FRCD - .section(delete) \(sectionIndex)")
            if !userMovingCells {
                tableView?.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
            }
        default:
            Log.fatal("FRCD - .section(??) Not sure what to do with \(type.rawValue)")
        }
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {
        // Debug tracing...
        switch type {
        case .delete:
            Log.tableLog("FRCD - .row(delete) \(indexPath!)")
        case .move:
            Log.tableLog("FRCD - .row(move) \(indexPath!) to \(newIndexPath!)")
        case .update:
            Log.tableLog("FRCD - .row(update) \(indexPath!)")
        case .insert:
            Log.tableLog("FRCD - .row(insert) \(newIndexPath!)")
        }

        // Bail immediately if the events are driven by user direct manipulation, in which
        // case the UI has already been updated by UITableView and we can only make things
        // look ugly or wrong.
        //
        guard !userMovingCells else {
            Log.tableLog("FRCD - bail - userMovingCells")
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
        Log.tableLog("FRCD - .controllerDidChangeContent - userMovingCells = \(userMovingCells)")
        if !userMovingCells {
            tableView?.endUpdates()
        }
        delegate?.objectsChanged()
    }

    public func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else {
            Log.fatal("Header isn't a header :/")
        }
        header.textLabel?.textColor = .white
        header.contentView.backgroundColor = .darkText
    }
}
