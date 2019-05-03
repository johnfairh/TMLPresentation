//
//  PagerPresenterVC.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import UIKit

open class PresentablePagerVC<PresenterViewInterface: PagerPresenterInterface> :
    PresentableBasicPagerVC<PresenterViewInterface>, UIPageViewControllerDataSource {

    open var pageViewControllerName: String!

    open override func viewDidLoad() {
        Log.assert(pageViewControllerName != nil, message: "Forgot to set page VC name")
        dataSource = self
        super.viewDidLoad()
        presenter.refresh = { [unowned self] in self.layoutPages() }
        layoutPages()
    }

    var pageViewControllers: [UIViewController] = []

    var pageCount: Int {
        return presenter.pageCount
    }

    func layoutPages() {
        pageViewControllers = (0..<pageCount).map { pageIndex in
            let pageVc = storyboard!.instantiateViewController(withIdentifier: pageViewControllerName)
            let pagePresenter = presenter.presenterForPage(index: pageIndex)
            PresenterUI.bind(viewController: pageVc, presenter: pagePresenter)
            return pageVc
        }

        if pageViewControllers.count > 0 {
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
        return 0 // ??? I don't understand exactly
    }
}
