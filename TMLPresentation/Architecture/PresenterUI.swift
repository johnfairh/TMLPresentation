//
//  PresenterUI.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import UIKit

public protocol Presentable: class {
    associatedtype PresenterViewInterface
    var presenter: PresenterViewInterface! { get set }
}

/// This doesn't work because there's no way to get hold of the `Presentable` -- no existentials
/// for protocols with associated types.  See `PresenterUI.bind`.
///
//extension Presentable {
//    func bind<PresenterType: Presenter>(presenter: PresenterType) where PresenterType.ViewInterfaceType == MyPresenter {
//        guard let presenterViewType = presenter as? MyPresenter else {
//            Log.fatal("Presenter does not conform to expected type")
//        }
//        self.presenter = presenterViewType
//    }
//}

/// Base class for regular view controllers with presenters
open class PresentableVC<PresenterViewInterface>: UIViewController, Presentable, SwipeDismissable {
    public var swipeDismisser: NSObject?
    public var presenter: PresenterViewInterface!
}

/// Base class for table-view controllers with presenters.
/// See `PresentableTableVC` for a version with more smarts and common functions.
open class PresentableBasicTableVC<PresenterViewInterface>: UITableViewController, Presentable, SwipeDismissable {
    public var swipeDismisser: NSObject?
    public var presenter: PresenterViewInterface!
}

/// Base class for page-view controllers with presenters.
/// See `PresentablePagerVC` for a version with more smarts and common functions.
open class PresentableBasicPagerVC<PresenterViewInterface>: UIPageViewController, Presentable {
    public var presenter: PresenterViewInterface!
}

/// Namespace
public enum PresenterUI {
    /// Bind a view controller to its presenter.  This just means setting the `presenter` property
    /// on the VC to the presenter.  But getting the types right is a pain.  Most of the ugliness
    /// is due to not being able to use protocols with associated types as existentials.
    public static func bind<PresenterType: Presenter>(viewController: UIViewController, presenter: PresenterType) {
        guard let presenterViewInterface = presenter as? PresenterType.ViewInterfaceType else {
            Log.fatal("Presenter does not conform to ViewInterfaceType")
        }

        if let presentableTableVc = viewController as? PresentableBasicTableVC<PresenterType.ViewInterfaceType> {
            presentableTableVc.presenter = presenterViewInterface
        } else if let presentableVc = viewController as? PresentableVC<PresenterType.ViewInterfaceType> {
            presentableVc.presenter = presenterViewInterface
        } else if let presentableVc = viewController as? PresentableBasicPagerVC<PresenterType.ViewInterfaceType> {
            presentableVc.presenter = presenterViewInterface
        } else {
            Log.fatal("Can't figure out presentable type for \(viewController)")
        }
    }

    /// Load a view controller from the root storyboard
    public static func loadViewController(id: String) -> UIViewController {
        guard let window = UIApplication.shared.windows.first,
            let rootVC = window.rootViewController,
            let storyboard = rootVC.storyboard else {
                Log.fatal("Can't locate storyboard")
        }
        return storyboard.instantiateViewController(withIdentifier: id)
    }
}
