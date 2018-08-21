//
//  PresenterUI.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation
import UIKit

///
/// TabbedDirectorServices -- use for managing a UI based in a tab controller
/// with each tab having a nav controller.
///
open class TabbedDirectorServices<AppDirectorType>: DirectorServices<AppDirectorType>, UITabBarControllerDelegate {
    private var tabBarViewController: UITabBarController!
    
    /// Provide app director instance, the window to put view controllers in, and the name of the tab VC
    public init(director: AppDirectorType, window: UIWindow, tabBarVcName: String) {
        super.init(director: director, window: window)
        
        guard let controller = loadVc(tabBarVcName) as? UITabBarController else {
            Log.fatal("VC \(tabBarVcName) is not a UITabBarController")
        }
        self.tabBarViewController = controller
        controller.delegate = self
    }

    /// Routines to dynamically switch between tabs and have the presenters understand
    private var presenterInvocationFunctions: [Int : (AnyObject) -> Void] = [:]

    /// During initialization, before 'presentUI', configure a tab's VC with a presenter.
    ///
    /// The tab's VC may be wrapped in a nav controller - this is skipped.
    ///
    /// The tab is assumed to be managing some kind of live object or more usually a set
    /// of live objects.  These are expressed by the `queryResults` which is a bunch of
    /// DB queries.  In the case of a singular object this query will produce just the one
    /// object -- but we still pass the query here, not the object, to avoid having to fetch/
    /// create/handle errors up front.
    public func initTab<ModelObjectType, PresenterType>(tabIndex: Int,
                                                        rootModel: Model,
                                                        queryResults: ModelResultsSet,
                                                        presenterFn: MultiPresenterFn<AppDirectorType, ModelObjectType, PresenterType>,
                                                        picked: @escaping PresenterDone<ModelObjectType> = { _ in })
    where ModelObjectType: ModelObject, PresenterType: Presenter {

        guard let vcInTab = tabBarViewController.viewControllers?[tabIndex] else {
            Log.fatal("Tab \(tabIndex) missing")
        }

        let targetVC: UIViewController
        if let navController = vcInTab as? UINavigationController {
            targetVC = navController.viewControllers[0]
        } else {
            targetVC = vcInTab
        }

        let presenter = presenterFn(director, rootModel, queryResults, .multi(.manage), picked)

        // We can't store an array of 'Presenter's so wrap up the refs to the specific type
        presenterInvocationFunctions[tabIndex] = { any in
            guard let invtype = any as? PresenterType.InvocationType else {
                Log.fatal("Wrong invocation type provided.  Expected \(PresenterType.InvocationType.self) got \(any)")
            }
            presenter.invoke(with: invtype)
        }

        PresenterUI.bind(viewController: targetVC, presenter: presenter)
    }
    
    /// Call when the model layer is all ready to go, enables the UI
    public func presentUI() {
        window.rootViewController = tabBarViewController
    }
    
    /// Helper to obtain the currently presented nav controller/view controller
    private var currentMaybeNavController: UINavigationController? {
        guard let selectedVC = tabBarViewController.selectedViewController else {
            Log.fatal("No tab selected?")
        }

        let navController: UINavigationController

        if selectedVC is UINavigationController {
            navController = selectedVC as! UINavigationController
        } else if selectedVC.presentedViewController is UINavigationController {
            navController = selectedVC.presentedViewController as! UINavigationController
        } else {
            return nil
        }
        // navController is the NavVC at the bottom of any stack.  We want the one at the top.

        guard let topNavVC = navController.visibleViewController?.navigationController else {
            Log.fatal("No presented nav view controller?")
        }

        return topNavVC

    }

    public override var currentNavController: UINavigationController {
        return currentMaybeNavController!
    }

    public override var currentViewController: UIViewController {
        guard let navController = currentMaybeNavController else {
            return tabBarViewController.selectedViewController!
        }
        return navController
    }
    
    /// Switch the UI to a given tab displaying a set of results appropriate for that tab
    /// but filtered in some way, with a UI control visible indicating the filter is applied.
    public func animateToTab(tabIndex: Int, invocationData: AnyObject) {
        guard let viewControllers = tabBarViewController.viewControllers else {
            Log.fatal("Missing view controller stack")
        }
        
        guard let navController = viewControllers[tabIndex] as? UINavigationController else {
            Log.fatal("Confused about view controllers for \(tabIndex)")
        }

        guard let presenterInvocation = presenterInvocationFunctions[tabIndex] else {
            Log.fatal("No presenter invocation for tab \(tabIndex)")
        }

        // Blow away stack of destination tab.
        // (this might be bad - whinging in the console...)
        navController.popToRootViewController(animated: false)

        // Now do the animation to bring across the new state, then update the UI
        animateToTab(navController) {
            self.tabBarViewController.selectedViewController = navController

            // Get the presenter to sort out the new state.  Originally wanted to
            // do this before the animation, but hitting problems with uikit (searchcontroller)
            // not updating properly unless actually on-screen.
            presenterInvocation(invocationData)
        }
    }
    
    /// Animate the transition between tabs - used when doing this programatically to give the user
    /// a clue what is happening.  Kludged together from stackoverflow answers.
    private func animateToTab(_ destinationVC: UIViewController, andThen: @escaping () -> Void) {
        guard let currentVC = tabBarViewController.selectedViewController else {
            Log.fatal("No selected VC")
        }
        
        guard let currentIndex = tabBarViewController.viewControllers?.index(of: currentVC) else {
            Log.fatal("Can't find index of currentVC")
        }
        
        guard let destinationIndex = tabBarViewController.viewControllers?.index(of: destinationVC) else {
            Log.fatal("Can't find index of destVC")
        }
        
        guard let currentView = currentVC.view,
            let destinationView = destinationVC.view else {
                Log.fatal("Missing view")
        }
        
        // Direction of animation
        let leftToRight = destinationIndex > currentIndex
        
        Log.log("Director: animating from tab \(currentIndex) to \(destinationIndex)")
        
        // Temporarily mess with the view hierarchy for animation/coordinates
        currentView.superview!.addSubview(destinationView)
        tabBarViewController.view.isUserInteractionEnabled = false
        
        // Start dest exactly offscreen
        let startingCurrToDest = UIScreen.main.bounds.width * (leftToRight ? 1 : -1)
        destinationView.center = currentView.center
        destinationView.center.x += startingCurrToDest
        
        UIView.animate(withDuration: 0.5, delay: 0,
                       usingSpringWithDamping: 1, initialSpringVelocity: 0,
                       options: .curveEaseOut,
                       animations: {
                        // move dest + curr together to replace one with other
                        destinationView.center.x -= startingCurrToDest
                        currentView.center.x -= startingCurrToDest
        }) { finished in
            if finished {
                // fix up the views
                destinationView.removeFromSuperview()
                self.tabBarViewController.view.isUserInteractionEnabled = true
                
                // user completion
                andThen()
            }
        }
    }
}
