//
//  SwipeDismissal.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation

/// Object to manage swipe-to-dismiss of modal presentations
private class SwipeToDismisser: NSObject, UIAdaptivePresentationControllerDelegate {
    private weak var viewController: UIViewController?
    private let discard: () -> Void
    private let save: () -> Void

    public init(viewController: UIViewController,
                discard: @escaping () -> Void,
                save: @escaping () -> Void) {
        self.viewController = viewController
        self.discard = discard
        self.save = save

        super.init()

        viewController.isModalInPresentation = true
        viewController.navigationController?.presentationController?.delegate = self
    }

    deinit {
        viewController?.isModalInPresentation = false
        viewController?.navigationController?.presentationController?.delegate = nil
    }

    public func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            self.save()
        })

        alert.addAction(UIAlertAction(title: "Discard Changes", style: .destructive) { _ in
            self.discard()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        viewController?.present(alert, animated: true, completion: nil)
    }
}

/// Adopt by a `UIViewController` to enable change-aware swipe-to-dismiss
public protocol SwipeDismissable: class {
    var swipeDismisser: NSObject? { get set }
}

public extension SwipeDismissable where Self: UIViewController {
    /// Update the swipe-to-dismiss state of the view controller
    ///
    /// - Parameter changes: are there changes pending?  If `true` swipe-to-dismiss will trigger a query dialog.
    /// - Parameter discard: callback made when the user elects to cancel the flow.
    /// - Parameter save: callback made when the user elects to 'save' the flow.
    func updateSwipeDismiss(changes: Bool, discard: @escaping () -> Void, save: @escaping () -> Void) {
        if changes {
            guardSwipeDismiss(discard: discard, save: save)
        } else {
            allowSwipeDismiss()
        }
    }

    /// Have swipe-to-dismiss trigger a save/discard/cancel dialog
    func guardSwipeDismiss(discard: @escaping () -> Void, save: @escaping () -> Void) {
        if swipeDismisser == nil {
            swipeDismisser = SwipeToDismisser(viewController: self, discard: discard, save: save)
        }
    }

    /// Allow swipe-to-dismiss -- the VC will just be dismissed without notifications upstream.
    func allowSwipeDismiss() {
        swipeDismisser = nil
    }
}
