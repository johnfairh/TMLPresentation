//
//  Presenter.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

/// A Presenter is responsible for the business logic associated with a view.
/// Its implementation has no UIKit or View dependencies, but it does depend on the Model
/// and typically the Director.
///
/// Implementing a Presenter, let us say for view Xxx, requires two declarations:
/// 1) A protocol containing all services required by the corresponding View[Controller] class
///    Call this the XxxPresenterViewInterface.
/// 3) An implementation of the Presenter that adopts both the (1) protocol and the Presenter protocol
///    below.  Call this the XxxPresenter.
///
/// The XxxPresenter class should be unit-testable without UI.  It is instantiated via DirectorServices
/// typically from a routine in the App's Director using the init routine from the Presenter protocol.
///
@MainActor
public protocol Presenter {
    associatedtype AppDirectorType
    associatedtype ModelType
    associatedtype ModelObjectType
    associatedtype ViewInterfaceType
    associatedtype InvocationType = Void

    init(director: AppDirectorType,
         model: Model,
         object: ModelType?,
         mode: PresenterMode,
         dismiss: @escaping PresenterDone<ModelObjectType>)

    /// Some presenters persist and can be invoked by the director during their
    /// lifetime.  This interface, which by default does nothing, is called when
    /// this happens.
    func invoke(with data: InvocationType)
}

extension Presenter {
    public func invoke(with data: InvocationType) {}
}

/// A type of presenter that edits some kind of Thing and needs to participate in
/// a standard save/cancel/discard flow, orchestrated at a higher level.
@MainActor
public protocol EditablePresenter: Presenter {
    /// Does the Thing have any unsaved changes?
    var hasChanges: Bool { get }

    /// Is the Thing in a state that is valid for persistence?
    var canSave: Bool { get }

    /// Save the Thing and end the edit session.
    func save()

    /// End the edit session immediately.  Discard any changes to the Thing.
    func cancel()
}

/// The signature of a `Presenter.init` that manages one object.
public typealias SinglePresenterFn<AppDirectorType, ModelObjectType, PresenterType> =
    @MainActor (AppDirectorType, Model, ModelObjectType?, PresenterMode, @escaping PresenterDone<ModelObjectType>) -> PresenterType

/// The signature of a `Presenter.init` that manages multiple objects.
public typealias MultiPresenterFn<AppDirectorType, ModelObjectType, PresenterType> =
    @MainActor (AppDirectorType, Model, ModelResultsSet?, PresenterMode, @escaping PresenterDone<ModelObjectType>) -> PresenterType

/// The signature of a `Presenter.init` that doesn't manage any objects.
public typealias NulPresenterFn<AppDirectorType, PresenterType> =
    @MainActor (AppDirectorType, Model) -> PresenterType

/// The signature of a `Presenter.init` that doesn't manage any objects with a callback.
public typealias NulAckPresenterFn<AppDirectorType, PresenterType> =
    @MainActor (AppDirectorType, Model, @escaping () -> Void) -> PresenterType

/// PresenterMode - used as a hint from Director for Presenter/View combinations that serve in
/// multiple roles.
public enum PresenterMode {

    /// Modes for single-object presenters
    public enum Single {
        /// View is expected to create a new instance, is presented modally, must call 'dismiss'
        /// to dismiss with any result (which should be nil for a cancellation)
        case create

        /// View is expected to create a new instance based on the one passed in and act like
        /// `create`.
        case dup

        /// View is of an existing instance, any editting must be live.  May call 'dismiss'
        /// to dismiss the view, any result passed is ignored.
        case view

        /// View is expected to edit an existing instance.  Must call 'dismiss' but can pass
        /// `nil` to indicate cancellation which means the model changes will be discarded.
        case edit
    }

    /// Modes for multi-object presenters
    public enum Multi {
        /// Fully-powered table view with edit/create buttons
        case manage

        /// Table view being invoked to just choose an existing instance, no chrome or editting.
        case pick

        /// Table view is embedded inside other view controllers but still editable.
        case embed
    }

    /// Presenter is managing multiple objects
    case multi(Multi)

    /// Presenter is managing a single object
    case single(Single)

    // MARK: Utilities to make nesting more tolerable

    public var singleType: Single? {
        if case let .single(singleType) = self {
            return singleType
        }
        return nil
    }

    public func isSingleType(_ type: Single) -> Bool {
        guard let sType = singleType else {
            return false
        }
        return sType == type
    }

    public var multiType: Multi? {
        if case let .multi(multiType) = self {
            return multiType
        }
        return nil
    }

    public func isMultiType(_ type: Multi) -> Bool {
        guard let mType = multiType else {
            return false
        }
        return mType == type
    }
}

/// Interface back to Director from Presenter - indicate that the use case is complete.
public typealias PresenterDone<ModelObjectType> = (ModelObjectType?) -> Void
