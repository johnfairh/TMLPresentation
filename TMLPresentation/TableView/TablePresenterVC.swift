//
//  PresenterUI.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import UIKit

/// UI class to slot in at the top of the tableview.
///
/// REMEMBER THIS CLASS IS REFERENCED FROM STORYBOARDS!
///
/// SO DO NOT RENAME IT OR SUCCUMB TO TEMPTATION OF MAKING IT PRIVATE!
///
final class TableFilterView: UIView {
    var done: (() -> Void)?
    @IBOutlet weak var filterLabel: UILabel!
    
    func configure(_ label: String, done: @escaping ()->Void) {
        filterLabel.text = "Filter: "+label
        self.done = done
    }
    
    @IBAction func clearFilterTapped(_ sender: UIButton) {
        guard let done = done else {
            Log.fatal("Missing callback")
        }
        done()
    }
    
    /// Add a little line to separate the filter from the table cells, trying to mimic
    /// the one between the nav header and the tableview.
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            Log.fatal("Eek no graphics context")
        }
        context.setLineWidth(1)
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.move(to: CGPoint(x: 0.0, y: bounds.height))
        context.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
        context.strokePath()
    }
}

/// Featureful tableview class.
/// Cares about view stuff -- filter bar, picker, create button, search controller
/// Cares about queries.

open class PresentableTableVC<PresenterViewInterface: TablePresenterInterface> :
    PresentableBasicTableVC<PresenterViewInterface>,
    UISearchResultsUpdating,
    UISearchBarDelegate {

    private var tableFilterView: TableFilterView?

    open override func viewDidLoad() {
        super.viewDidLoad()

        initEditBarButton()
        initAddBarButton()
        initSegmentBarButton()
        initTableFilter()
    }

    // MARK: - Edit Bar Button

    private func initEditBarButton() {
        if presenter.shouldEnableExtraControls {
            // want the 'edit/done' button
            navigationItem.leftBarButtonItem = editButtonItem
        }
    }

    // MARK: - Add Bar Button

    // If the table is supposed to have an 'add' menu-bar button then it will have been created
    // in interface builder and be present already.  If we find it, we hook it up manually and
    // provide a method that subclasses can override to do what they want on a press.
    private func initAddBarButton() {
        if presenter.shouldEnableExtraControls {
            if let addBarButton = navigationItem.rightBarButtonItem,
                addBarButton.target == nil {
                // We are in manage presentation mode + we have an unadopted right-nav button
                // that we assume is an 'add' button.  Hook it up.
                addBarButton.target = self
                addBarButton.action = #selector(self.addBarButtonPressed)
            }
        } else {
            // 'pick/embed' mode - hide any 'add' button
            navigationItem.rightBarButtonItem = nil
        }
    }

    @objc func addBarButtonPressed(_ sender: UIBarButtonItem) {
        presenter.createNewObject()
    }

    // MARK: - Segment title query thingy

    // If the table has a filtering control defined then we have to locate and hook it up
    private func initSegmentBarButton() {
        if presenter.shouldEnableExtraControls {
            if let segbar = navigationItem.titleView as? UISegmentedControl {
                segbar.addTarget(self, action: #selector(self.segmentBarButtonPressed), for: .valueChanged)
            }
        } else {
            navigationItem.titleView = nil
        }
    }

    @objc func segmentBarButtonPressed(_ sender: UISegmentedControl) {
        guard let segmentTitle = sender.titleForSegment(at: sender.selectedSegmentIndex) else {
            fatalError("No segment title!")
        }
        presenter.currentResultsName = segmentTitle
    }

    // MARK: - Filtering

    private func initTableFilter() {
        if let header = tableView.tableHeaderView as? TableFilterView {
            tableFilterView = header
            tableView.tableHeaderView = nil
        }
    }

    public func setFilter(_ filteredResults: ModelResultsSet, filterName: String) {
        guard let tableFilterView = tableFilterView else {
            Log.fatal("UI not configured for filtering")
        }

        // Set up the UI, dismiss filter when clicked
        tableFilterView.configure(filterName, done: clearFilter)
        tableView.tableHeaderView = tableFilterView

        // Set up the new query, will refresh the data
        presenter.filteredResults = filteredResults
    }

    public func clearFilter() {
        tableView.tableHeaderView = nil
        presenter.filteredResults = nil
    }

    // MARK: - Search

    /// Call during `viewDidLoad` to enable a search controller.
    /// `updateTableForSearch` is called when anything changes in the searchbar.
    public func enableSearch(scopes: [String]) {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.scopeButtonTitles = scopes
        searchController.searchBar.tintColor = UIColor(named: "TintColour")


        // VERY IMPORTANT TO NOT SET `showsScopeBar`
        //
        // The system figures it out from `scopeButtonTitles`.
        // If you set it manually then the scope bar shows up at weird
        // times including during animated push-pop-VC transitions.
        //
        // It's like this field means "show the scope bar at inconvenient
        // times as well as when it should be shown".
        //
        // searchController.searchBar.showsScopeBar = scopes.count > 0
        //
        searchController.searchBar.delegate = self
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }

    /// Refresh the search when the scope changes
    public func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        Dispatch.toForeground {
            self.updateSearchResults(for: self.navigationItem.searchController!)
        }
    }

    /// Pull out the essentials and call out to subclass
    public func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        let text = searchBar.text ?? ""
        updateTableForSearch(text: text, scopeIndex: searchBar.selectedScopeButtonIndex)
    }

    open func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return true
    }

    /// Override to implement a search
    open func updateTableForSearch(text: String, scopeIndex: Int) {
    }
}
