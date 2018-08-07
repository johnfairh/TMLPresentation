//
//  TablePresenter.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

/// Protocol to describe common behaviours between all our tables.
///
/// The full table function is:
/// * Manage a set of named model results - a `ModelResultsSet`
///     * All results are of the same `ModelObject`-derived type
///     * The set can be singular (just one results)
/// * The view knows the results names and can change the visible one using
///   `currentResultsName`.
/// * The results-set can be temporarily modified using `filteredResults`.
///     * This 'filter' must be of the same `ModelObject`-derived type and share
///       the same results names as the base one.
///     * The filter is cleared by setting the filter to `nil`.
/// * Tables can operate in different modes to satisfy different use cases.
///     * If `shouldEnableExtraControls` then the view may enable a query-picker
///       bar, edit-mode, and create-new-object controls.
///
/// Works with `PresentableTableVC` on the UI side.
///
public protocol TablePresenterInterface {
    /// (input) The name of the currently displayed query
    var currentResultsName: String { get set }

    /// (input) Temporarily change the query-set; assign nil to clear
    var filteredResults: ModelResultsSet? { get set }

    /// (output) Register a callback to update the view
    var reload: ((ModelResults) -> Void)? { get set }

    /// (output) should the view display associated chrome (segbar, +/edit buttons)
    var shouldEnableExtraControls: Bool { get }

    /// (input) "+" button tapped, create a new object
    func createNewObject()
}

public extension TablePresenterInterface {
    /// By default do nothing (helps out views that never have the button)
    func createNewObject() {}
}

/// Common implementation of a presenter for a table view.
///
open class TablePresenter<AppDirectorType> {
    // Properties for our implementation
    private var mode:         PresenterMode.Multi
    private var modelResults: ModelResultsSet

    // Properties for subclass access.  This is very much tramp data but so useful.
    public var director: AppDirectorType
    public var model:    Model

    public init(director: AppDirectorType, model: Model, object: ModelResultsSet?, mode: PresenterMode) {
        guard let modelResults = object else { Log.fatal("Missing results for table presenter") }
        guard let multiMode = mode.multiType else { Log.fatal("Wrong mode for table presenter") }
        self.mode               = multiMode
        self.modelResults       = modelResults
        self.director           = director
        self.model              = model
        self.currentResultsName = modelResults.defaultName
    }

    /// Do we want +/edit/etc.
    public var shouldEnableExtraControls: Bool {
        return mode == .manage
    }

    /// Does presentation mode permit editting?
    public var isEditable: Bool {
        return mode == .manage || mode == .embed
    }

    /// Examine all settings to vend the active query
    public var currentResults: ModelResults {
        let activeResultsSet = filteredResults ?? modelResults
        guard let results = activeResultsSet.resultsSet[currentResultsName] else {
            Log.fatal("Query results does not contain query name \(currentResultsName)")
        }
        return results
    }

    /// Update the view with the active query results
    private func refreshView() {
        reload?(currentResults)
    }

    /// Callback from view to reload the table
    public var reload: ((ModelResults) -> Void)? {
        didSet {
            refreshView()
        }
    }

    /// Change the displayed query
    public var currentResultsName: String {
        didSet {
            refreshView()
        }
    }

    /// Filtering is UI-concept name for temporarily replacing the query-set with
    /// a different one (generated somewhere by filtering the existing one).
    ///
    /// The `currentResultsName` is independent -- the new query results must have
    /// the same query names as the base one.
    ///
    /// Just overwrite any existing filter.
    public var filteredResults: ModelResultsSet? {
        didSet {
            refreshView()
        }
    }

    // MARK: Search support -- delay DB query until typing stops
    enum SearchDelayState {
        case idle
        case delaying
        case delaying_again
    }

    public typealias TablePresenterSearchHandler = (String, Int) -> ModelResultsSet?

    private var searchDelayState: SearchDelayState = .idle
    private var searchText = ""
    private var searchType = 0
    private var searchHandler: TablePresenterSearchHandler?

    /// Call from presenter to respond to a search request
    public func handleSearchUpdate(text: String, type: Int, handler: @escaping TablePresenterSearchHandler) {
        if text.isEmpty {
            searchDelayState = .idle
            if filteredResults != nil {
                filteredResults = nil
            }
        } else {
            searchText = text
            searchType = type
            searchHandler = handler

            switch searchDelayState {
            case .idle:
                delaySearch()
            case .delaying:
                searchDelayState = .delaying_again
            case .delaying_again:
                break
            }
        }
    }

    func delaySearch() {
        searchDelayState = .delaying
        Dispatch.toForegroundAfter(milliseconds: 150, block: updateSearchResultsDelayed)
    }

    func updateSearchResultsDelayed() {
        switch searchDelayState {
        case .idle:
            break
        case .delaying_again:
            delaySearch()
        case .delaying:
            searchDelayState = .idle
            filteredResults = searchHandler!(searchText, searchType)
        }
    }
}

// MARK: Moving objects

extension TablePresenter {
    /// Helper for clients that support user-driven moving of rows.
    /// We take the simple-but-working approach of grabbing all the objects,
    /// rearranging them, and then "renumbering" them in order to reflect
    /// that.
    ///
    /// This version works on the global objects list.
    public func moveAndRenumber(fromRow: Int, toRow: Int, sortOrder: ModelSortOrder) {
        guard var modelObjects = currentResults.fetchedObjects as? [ModelObject] else {
            fatalError("Confused somewhere, maybe before viewDidLoad()?")
        }

        Log.log("MoveAndRenumber, \(fromRow) -> \(toRow)")

        let object = modelObjects.remove(at: fromRow)
        modelObjects.insert(object, at: toRow)

        // get the list of indexes for reallocation
        var indexArray: [Int64] = []

        for object in modelObjects {
            indexArray.append(object.getSortOrder(sortOrder))
        }

        // sort
        indexArray.sort()
        if !sortOrder.ascending {
            indexArray.reverse()
        }

        // and reassign
        var index = 0
        for object in modelObjects {
            object.setSortOrder(sortOrder, newValue: indexArray[index])
            index += 1
        }
    }

    /// Move and renumber in a sectioned table
    public func moveAndRenumber(fromSectionName: String, fromRowInSection: Int,
                                toSectionName: String, toRowInSection: Int,
                                sortOrder: ModelSortOrder) {
        let fromSection = getSectionPosition(controller: currentResults, sectionName: fromSectionName)
        let toSection = getSectionPosition(controller: currentResults, sectionName: toSectionName)

        let fromSectionIdx = fromSection.index
        let toSectionIdx = toSection.index

        let fromSectionOffset = fromSection.rowOffset
        let toSectionOffset = toSection.rowOffset

        let fudge = (toSectionIdx > fromSectionIdx) ? -1 : 0

        moveAndRenumber(fromRow: fromSectionOffset + fromRowInSection,
                        toRow: toSectionOffset + toRowInSection + fudge,
                        sortOrder: sortOrder)
    }

    private func getSectionPosition<T>(controller: NSFetchedResultsController<T>,
                                       sectionName: String) -> (index: Int, rowOffset: Int, rows: Int) {
        guard let sections = controller.sections else {
            Log.fatal("Controller has no sections")
        }
        var rowOffset = 0, index = 0
        for section in sections {
            if section.name != sectionName {
                rowOffset += section.numberOfObjects
                index += 1
            } else {
                return (index: index, rowOffset: rowOffset, rows: section.numberOfObjects)
            }
        }
        Log.fatal("Can't find section '\(sectionName)'")
    }

    public func getSectionRowCount(sectionName: String) -> Int {
        return getSectionPosition(controller: currentResults, sectionName: sectionName).rows
    }

    public func getSectionIndex(sectionName: String) -> Int {
        return getSectionPosition(controller: currentResults, sectionName: sectionName).index
    }
}
