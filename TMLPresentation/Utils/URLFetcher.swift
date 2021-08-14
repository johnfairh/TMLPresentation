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
    private var urlString: String

    public init(url: String) {
        self.urlString = url
    }

    public func fetch() async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw TMLError("URL construction failed \(urlString)")
        }
        let session = URLSession.shared
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResp = response as? HTTPURLResponse else {
                throw TMLError("Bad response type: \(response)")
            }
            guard httpResp.statusCode == 200 else {
                throw TMLError("Bad HTTP status: \(httpResp)")
            }
            return data
        } catch {
            let msg = "Network error \(error.localizedDescription). "
            Log.log("Failure fetching data: \(msg)")
            throw TMLError(msg)
        }
    }
}
