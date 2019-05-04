//
//  PagerPresenterVC.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import UIKit

/// This is the shared function for a `UIPageViewController` known as a _Pager_ here.
///
/// The minimum subclasses have to do is set `pageViewControllerName` during `viewDidLoad()`
/// Subclasses can implement the delegate but must not provide a datasource - we do that.
///
open class PresentablePagerVC<PresenterViewInterface: PagerPresenterInterface> :
    PresentableBasicPagerVC<PresenterViewInterface>, UIPageViewControllerDataSource {

    /// Subclasses must set this before our `viewDidLoad()` is called.
    open var pageViewControllerName: String!

    open override func viewDidLoad() {
        Log.assert(pageViewControllerName != nil, message: "Forgot to set page VC name")
        dataSource = self
        super.viewDidLoad()
        presenter.refresh = { [unowned self] in self.layoutPages() }
        layoutPages()
    }

    // Mad workaround :(
    // Doing this at any earlier (sensible) point gets overridden somewhere
    // inside UIKit.
    override open func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        for subView in view.subviews {
            if let pageControl = subView as? UIPageControl {
                pageControl.hidesForSinglePage = true
                break
            }
        }
    }

    var pageViewControllers: [UIViewController] = []

    var pageCount: Int {
        return presenter.pageCount
    }

    func layoutPages() {
        pageViewControllers = (0..<pageCount).map { pageIndex in
            let pageVc = PresenterUI.loadViewController(id: pageViewControllerName)
            let pagePresenter = presenter.presenterForPage(index: pageIndex)
            PresenterUI.bind(viewController: pageVc, presenter: pagePresenter)
            return pageVc
        }

        if pageCount > 0 {
            setViewControllers([pageViewControllers[0]], direction: .forward, animated: false)
        }
    }

    // MARK: UIPageViewControllerDataSource

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let index = pageViewControllers.firstIndex(of: viewController) else {
            Log.fatal("Confused.com - can't find \(viewController) in our page list")
        }
        guard index > 0 else {
            return nil
        }
        return pageViewControllers[index - 1]
    }

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let index = pageViewControllers.firstIndex(of: viewController) else {
            Log.fatal("Confused.com - can't find \(viewController) in our page list")
        }
        guard index < pageCount - 1 else {
            return nil
        }
        return pageViewControllers[index + 1]
    }

    public func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return pageCount
    }

    public func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        Log.log("UIPageViewControllerDataSource.presentationIndex(for:)")
        return 0 // Set from presenter somehow, only affects display during setViewControllers()
    }
}
