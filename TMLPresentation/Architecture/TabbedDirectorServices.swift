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
open class TabbedDirectorServices<AppDirectorType>: DirectorServices<AppDirectorType> {
    private var tabBarViewController: UITabBarController!
    
    /// Provide app director instance, the window to put view controllers in, and the name of the tab VC
    public init(director: AppDirectorType, window: UIWindow, tabBarVcName: String) {
        super.init(director: director, window: window)
        
        guard let controller = loadVc(tabBarVcName) as? UITabBarController else {
            Log.fatal("VC \(tabBarVcName) is not a UITabBarController")
        }
        self.tabBarViewController = controller
    }
    
    /// During initialization, before 'presentUI', configure the default action for selecting
    /// table rows.
    public func initTab<ModelObjectType, PresenterType>(tabIndex: Int,
                                                        rootModel: Model,
                                                        queryResults: ModelResultsSet,
                                                        presenterFn: MultiPresenterFn<AppDirectorType, ModelObjectType, PresenterType>,
                                                        picked: @escaping PresenterDone<ModelObjectType>)
        where ModelObjectType: ModelObject,PresenterType: Presenter {
        guard let navController = tabBarViewController.viewControllers?[tabIndex] as? UINavigationController else {
            Log.fatal("Tab \(tabIndex) missing or not a UINavigationController")
        }

        let presenter = presenterFn(director, rootModel, queryResults, .multi(.manage), picked)

        PresenterUI.bind(viewController: navController.viewControllers[0], presenter: presenter)
    }
    
    /// Call when the model layer is all ready to go, enables the UI
    public func presentUI() {
        window.rootViewController = tabBarViewController
    }
    
    /// Helper to obtain the currently presented nav controller
    public override var currentNavController: UINavigationController {
        // Start with current tab
        guard let tabNavController = tabBarViewController.selectedViewController as? UINavigationController else {
            Log.fatal("doh currently selected is not a nav controller??")
        }
        
        guard let presentedNavVC = tabNavController.visibleViewController?.navigationController else {
            Log.fatal("No presented nav view controller?")
        }
        
        return presentedNavVC
    }
    
    /// Switch the UI to a given tab displaying a set of results appropriate for that tab
    /// but filtered in some way, with a UI control visible indicating the filter is applied.
    public func switchToFilteredTab<TablePresenterType>(tabIndex: Int, tableResults: ModelResultsSet, filterName: String, presenterType: TablePresenterType.Type) where TablePresenterType : TablePresenterInterface {
        guard let viewControllers = tabBarViewController.viewControllers else {
            Log.fatal("Missing view controller stack")
        }
        
        guard let navController = viewControllers[tabIndex] as? UINavigationController else {
            Log.fatal("Confused about view controllers for \(tabIndex)")
        }

        // TODO: well this is a bit of a mess, need to somehow lift up what's needed here into concrete.
        // (or wait until Swift fixes protocol existentials)
        guard let modelQueryTable = navController.viewControllers[0] as? PresentableTableVC<TablePresenterType> else {
            Log.fatal("Can't find the goal table VC")
        }

        // Force view to load + run if we haven't done that yet!
        _ = modelQueryTable.tableView
        
        modelQueryTable.setFilter(tableResults, filterName: filterName)
        navController.popToRootViewController(animated: false)
        
        animateToTab(navController) {
            self.tabBarViewController.selectedViewController = navController
            
            // This reload fixes the case where app starts on eg. favgoals page,
            // user switches to chars and clicks one.  Now the goals tab load for
            // the first time, while not on-screen yet.  The CD query executes OK
            // but for some reason the tableview will not display the contents --
            // reloadData() causes a 'numberOfSections' / 'numberOfRowsInSection'
            // sequence giving the correct answers, but then no calls to 'cellForRowAt'.
            //
            // Only way I have found to make it work is this next, which causes a new
            // CD query to be run and a rebinding of the tableview's datasource/delegate.
            modelQueryTable.setFilter(tableResults, filterName: filterName)
        }
    }
    
    /// Animate the transition between tabs - used when doing this programatically to give the user
    /// a clue what is happening.  Kludged together from stackoverflow answers.
    /// Not perfect - some strange transparency effect happening with the bars.
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
                Log.log("Director: animation done, cleaning up")
                // fix up the views
                destinationView.removeFromSuperview()
                self.tabBarViewController.view.isUserInteractionEnabled = true
                
                // user completion
                andThen()
            }
        }
    }
}
