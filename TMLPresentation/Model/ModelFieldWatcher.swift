//
//  ModelFieldWatcher.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

//
// This is roughly like `NSFetchedResultsController` but for a field
// request, ie. when the `NSFetchRequest` is using `.dictionaryResultType`
// in order to perform some shenanigans at the SQL level like summing a
// field or uniquing it.
//
// The change reporting is very coarse: whenever the context commits the
// query is re-run in the background and the results reported.
//
// This works fine with our 'root context is always saved' approach but
// will just go out of sync used in other contexts or if we get lazier
// about saving the root.
//
// This can't quite be a simple map from 'context-saved' to 'results' because
// we need a value up-front eagerly available without having to wait for a
// change.

/// A type for the query the delegate is required to build
public typealias ModelFieldFetchRequest = NSFetchRequest<NSDictionary>

/// A type for the results of a field fetch request
public typealias ModelFieldResults = [[String : AnyObject & Sendable]]

/// Wrapper sequence for field-watching.  Use `Model.fieldResultsSequence(...)` to create.
public struct ModelFieldResultsSequence: AsyncSequence {
    public typealias AsyncIterator = Iterator
    public typealias Element = ModelFieldResults

    private let fetchRequest: ModelFieldFetchRequest
    private let baseModel: Model

    init(model: Model, fetchRequest: ModelFieldFetchRequest) {
        self.fetchRequest = fetchRequest
        self.baseModel = model
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(self)
    }

    public final class Iterator: AsyncIteratorProtocol {
        private let seq: ModelFieldResultsSequence
        private let bgModel: Model
        private var sentFirst: Bool
        private var rest: AsyncMapSequence<NotificationCenter.Notifications, ModelFieldResults>.AsyncIterator!

        init(_ seq: ModelFieldResultsSequence) {
            self.seq = seq
            self.bgModel = seq.baseModel.createChildModel(background: true)
            self.sentFirst = false
            self.rest = nil
            self.rest = seq.baseModel.notifications(name: .NSManagedObjectContextDidSave).map { _ in
                await self.query()
            }.makeAsyncIterator()
        }

        public func next() async -> ModelFieldResults? {
            guard !Task.isCancelled else {
                return nil
            }

            guard sentFirst else {
                sentFirst = true
                return await query()
            }

            return await rest.next()
        }

        private func query() async -> ModelFieldResults {
            await withCheckedContinuation { continuation in
                bgModel.perform { model in
                    let results = model.createFieldResults(fetchRequest: self.seq.fetchRequest)
                    continuation.resume(returning: results)
                }
            }
        }
    }
}
