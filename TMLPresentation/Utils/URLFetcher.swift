//
//  URLFetcher.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation

/// Type to wrap up async http fetch with cancellation.
///
/// Transfer starts immediately and calls back on the UI thread.
/// `cancel()` can be called which guarantees no callback will
/// be made (the transfer may still continue in the background)
public struct URLFetcher {
    private var done: (Data?, String?) -> Void
    private var urlString: String
    private var dataTask: URLSessionDataTask?
    private var requestCancel: Bool

    public init(url: String, done: @escaping (Data?, String?) -> Void ) {
        self.done = done
        self.urlString = url
        self.requestCancel = false

        startFetch()
    }

    private mutating func startFetch() {
        guard let url = URL(string: urlString) else {
            sendDone(error: "URL construction failed \(urlString)")
            return
        }
        let session = URLSession.shared
        dataTask = session.dataTask(with: url, completionHandler: fetchDone)
        dataTask!.resume()
    }

    private func fetchDone(_ data: Data?, response: URLResponse?, error: Error?) {
        if let data = data {
            sendDone(data: data)
        } else {
            Log.log("Failure fetching image.")
            var msg = "Error. "
            if let error = error {
                msg += "Network error \(error.localizedDescription). "
            }
            if let response = response {
                msg += "HTTP response \(response)."
            }
            Log.log("Failure fetching image: \(msg)")
            sendDone(error: msg)
        }
    }

    private func sendDone(data: Data? = nil, error: String? = nil) {
        Dispatch.toForeground {
            if !self.requestCancel {
                self.done(data, error)
            }
        }
    }

    public mutating func cancel() {
        Log.assert(!requestCancel)
        requestCancel = true
    }
}
