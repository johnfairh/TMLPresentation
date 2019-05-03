//
//  PagerPresenter.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation

/// Stuff pager VC needs to call in presenter
public protocol PagerPresenterInterface {

    /// How many pages are there?
    var pageCount: Int { get }

    /// Type of the presenter for a page [Swift PAT limitation...]
    associatedtype PagePresenter: Presenter

    /// Presenter for a given page
    func presenterForPage(index: Int) -> PagePresenter

    /// Register for changes to page count
    var refresh: () -> Void { get set }
}

/// Generic presenter for pagers
open class PagerPresenter<AppDirectorType, ModelObjectType: ModelObject, PagePresenterType: Presenter> {

    // The results we are managing with one page per item
    private let modelResults: ModelResults
    private var modelResultsWatcher: ModelResultsWatcher<ModelObjectType>!

    // Hooks to the world for generating pages
    public let director: AppDirectorType
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
