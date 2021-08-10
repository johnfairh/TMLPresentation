//
//  PagerPresenter.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation

/// Minimal presenter for `UIPageViewController` designed to manage a core
/// data query with one page per entry, updated dynamically, and the same
/// (separate) presenter for each page.
///
/// Intended to work with `PagerPresenterVC`.

/// Stuff pager VC needs to call in presenter
@MainActor
public protocol PagerPresenterInterface {
    /// How many pages are there?
    var pageCount: Int { get }

    /// What is the current page?
    var pageIndex: Int { get set }

    /// Type of the presenter for a page [Swift PAT limitation...]
    associatedtype PagePresenter: Presenter

    /// Presenter for a given page
    func presenterForPage(index: Int) -> PagePresenter

    /// Register for changes to page count
    var refresh: () -> Void { get set }
}

extension PagerPresenterInterface {
    /// By default start at the first page; don't persiste anything.
    public var pageIndex: Int {
        get {
            return 0
        }
        set {
        }
    }
}

/// Generic presenter for pagers.
///
/// All subclasses have to do is call `init()` providing the constructor for
/// the per-page presenter.  The page VC is handled in `PagerPresenterVC`.
///
@MainActor
open class PagerPresenter<AppDirectorType, ModelObjectType: ModelObject, PagePresenterType: Presenter> {
    // The results we are managing with one page per item
    private let modelResults: ModelResults
    private var modelResultsWatcher: ModelResultsWatcher<ModelObjectType>!

    public var objects: [ModelObjectType] {
        return modelResultsWatcher.objects
    }

    // Hooks to the world for generating pages
    public var director: AppDirectorType
    public let model: Model
    public let pagePresenterFn: SinglePresenterFn<AppDirectorType, ModelObjectType, PagePresenterType>

    public init(director: AppDirectorType,
                model: Model,
                object: ModelResultsSet?,
                mode: PresenterMode,
                pagePresenterFn: @escaping SinglePresenterFn<AppDirectorType, ModelObjectType, PagePresenterType>) {
        Log.assert(mode.isMultiType(.manage), message: "Expected Multi-Manage")
        guard let modelResultsSet = object else { Log.fatal("Missing results for pager presenter") }
        self.modelResults = modelResultsSet.defaultResults
        self.director = director
        self.model = model
        self.modelResultsWatcher = nil
        self.pagePresenterFn = pagePresenterFn

        modelResultsWatcher = ModelResultsWatcher(modelResults: modelResults) { [unowned self] _ in
            self.refresh()
        }
        modelResults.issueFetch()
    }

    // MARK: PagerPresenterInterface

    public var pageCount: Int {
        return modelResultsWatcher.objects.count
    }

    public func presenterForPage(index: Int) -> PagePresenterType {
        return pagePresenterFn(director, model, modelResultsWatcher.objects[index], .single(.edit), { _ in })
    }

    public var refresh: () -> Void = {}
}
