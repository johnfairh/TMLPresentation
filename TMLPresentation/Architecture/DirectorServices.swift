//
//  DirectorServices.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation
import UIKit

///
/// DirectorServices is a library class that provides deep utilities for the
/// application-specific Director to manage the user interface.  The App Director
/// uses DirectorServices to instantiate Presenters, View[Controller]s, bind them
/// together to form use cases, present them, and provide any result.
///
/// Director Services provides use cases split into view<object>, edit<object>,
/// create<object>, pick<object>, and, for tabbed UIs, switch-to-tab automation.
///
/// DirectorServices manages creation of child models to separate object editting
/// from the main app context, and translates between models to hide all this from
/// views/presenters.
///
/// The AppDirector understands the structure of the app; DirectorServices understands
/// the iOS view controller stack.
///
/// The generic parameter passed to DirectorServices is the app's token class that is
/// passed in turn to the presenters.  There are no restrictions on this type - it is
/// typically a protocol offering services to presenters to invoke use cases.
///

///
/// DirectorServices -- use for managing a UI based in a navigation controller.
///
/// TODO: Make this actually work without the tab subclass!
///
open class DirectorServices<AppDirectorType>: NSObject {
    public let director:   AppDirectorType
    public let window:     UIWindow
    public let storyboard: UIStoryboard
    
    /// Give services the AppDirectorType token and the main window used to present view controllers
    public init(director: AppDirectorType, window: UIWindow) {
        self.director = director
        self.window   = window
        
        guard let storyboard = window.rootViewController?.storyboard else {
            Log.fatal("Rats, can't get hold of the storyboard")
        }
        self.storyboard = storyboard
    }
    
    // MARK: - View Controller helpers
    
    /// Shortcut helper to load a VC from the storyboard
    func loadVc(_ identifier: String) -> UIViewController {
        return storyboard.instantiateViewController(withIdentifier: identifier)
    }
    
    /// Get the current (top, visible) navigation controller.
    public var currentNavController: UINavigationController {
        
        Log.fatal("Not implemented")
        
        // TODO: -Refactor all this properly - consult UINav.visibleViewController, is it the same??
    }

    public var currentViewController: UIViewController {
        Log.fatal("Also not implemented")
    }
    
    /// Present a view of an existing object, pushed onto the current nav controller.
    /// No notification when the user clears the view.
    public func viewThing<PresenterType, ModelObjectType>(_ newVcIdentifier: String,
                   model: Model,
                   object: ModelObjectType,
                   presenterFn: SinglePresenterFn<AppDirectorType, ModelObjectType, PresenterType>)
        where PresenterType: Presenter
    {
        let viewController = loadVc(newVcIdentifier)

        let presenter = presenterFn(director, model, object, .single(.view)) { [weak viewController] _ in
            guard let navController = viewController?.navigationController else {
                Log.fatal("Not in a nav-controller - can't dismiss this way")
            }
            _ = navController.popViewController(animated: true)
        }

        PresenterUI.bind(viewController: viewController, presenter: presenter)

        currentNavController.pushViewController(viewController, animated: true)
    }
    
    /// Present a modal view to edit an existing object.
    /// The object + model that are given to the presenter are children so can be
    /// editted freely without affecting the parent model.
    /// When editting is over, whether it was cancelled or not, the done callback is
    /// made with the same object instance that was originally given along with any
    /// changes from the user's edit session.
    public func editThing<PresenterType,ModelObjectType>(_ newVcIdentifier: String,
                    model: Model,
                    object: ModelObjectType,
                    presenterFn: SinglePresenterFn<AppDirectorType, ModelObjectType, PresenterType>,
                    done: @escaping (ModelObjectType)->Void)
        where PresenterType: Presenter, ModelObjectType: ModelObject
    {
        let editThingVc        = loadVc(newVcIdentifier)
        let modalNavController = UINavigationController(rootViewController: editThingVc)

        modalNavController.navigationBar.barStyle = .black
        modalNavController.navigationBar.isTranslucent = false
        modalNavController.navigationBar.tintColor = UIColor(named: "TintColour")

        let editModel  = model.createChildModel()
        let editObject = object.convert(editModel)

        let presenter = presenterFn(director, editModel, editObject, .single(.edit)) {[weak self, weak editThingVc] _ in
            Log.log("Director: closing edit view")
            editThingVc?.view.endEditing(true)
            self?.currentViewController.dismiss(animated: true, completion: nil)
            done(object)
        }

        PresenterUI.bind(viewController: editThingVc, presenter: presenter)

        currentViewController.present(modalNavController, animated: true, completion: nil)
    }
    
    /// Present a modal view to create a new object.
    /// The object + model that are given to the presenter are children so can be
    /// editted freely without affecting the parent model.
    /// If the creation is successful then the done callback is made with the new object.
    /// If the user abandons the creation then no callback is made, the view is just
    /// dismissed.
    /// [this works fine in our use cases, should perhaps be more general though]
    public func createThing<PresenterType,ModelObjectType>(_ newVcIdentifier: String,
                    model: Model,
                    presenterFn: SinglePresenterFn<AppDirectorType, ModelObjectType, PresenterType>,
                    done: @escaping (ModelObjectType)->Void)
        where PresenterType: Presenter, ModelObjectType: ModelObject
    {
        let createThingVc      = loadVc(newVcIdentifier)
        let modalNavController = UINavigationController(rootViewController: createThingVc)

        modalNavController.navigationBar.barStyle = .black
        modalNavController.navigationBar.isTranslucent = false
        modalNavController.navigationBar.tintColor = UIColor(named: "TintColour")

        let editModel = model.createChildModel()

        let presenter = presenterFn(director, editModel, nil, .single(.create)) { [weak self, weak createThingVc] object in
            createThingVc?.view.endEditing(true)
            self?.currentViewController.dismiss(animated: true, completion: nil)

            guard let object = object else {
                Log.log("Director: object create view abandoned")
                // NO CALLBACK
                return
            }

            Log.log("Director: object create view completed with new object \(object)")
            let parentModelObject = object.convert(model)
            done(parentModelObject)
        }

        PresenterUI.bind(viewController: createThingVc, presenter: presenter)

        currentViewController.present(modalNavController, animated: true, completion: nil)
    }

    /// Push a table view onto the current navigation stack to let the user pick an object.
    /// The default table contents are according to the particular presenter but can be
    /// overridden using the 'results' parameter.
    /// If the user picks an object then the 'done' callback is made.
    /// If the user cancels the dialog then no callback is made.
    public func pickThing<ModelObjectType, PresenterType>(_ newVcIdentifier: String,
                   model: Model,
                   results: ModelResults,
                   presenterFn: MultiPresenterFn<AppDirectorType, ModelObjectType, PresenterType>,
                   done: @escaping (ModelObjectType) -> Void)
        where ModelObjectType: ModelObject, PresenterType: Presenter {

        let newVc = loadVc(newVcIdentifier)

        let presenter = presenterFn(director, model, results.asModelResultsSet, .multi(.pick)) { [weak self] pickedItem in
            Log.log("Director: pick object done with \(pickedItem!)")
            self?.currentNavController.popViewController(animated: true)
            done(pickedItem!)
        }

        PresenterUI.bind(viewController: newVc, presenter: presenter)

        currentNavController.pushViewController(newVc, animated: true)
    }
}
