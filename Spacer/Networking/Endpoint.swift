//
//  Endpoint.swift
//  Spacer
//
//  Describes a single NASA JSON endpoint. The API key is injected at request-build
//  time (never stored on the endpoint) so it stays out of cached/persisted URLs.
//

import Foundation

nonisolated struct Endpoint: Sendable {
    var host: String
    var path: String
    var queryItems: [URLQueryItem]

    init(host: String = "api.nasa.gov", path: String, queryItems: [URLQueryItem] = []) {
        self.host = host
        self.path = path
        self.queryItems = queryItems
    }

    /// Builds a GET request, appending `api_key`. Throws `.invalidURL` if components
    /// can't form a valid URL.
    func urlRequest(apiKey: String) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        var items = queryItems
        items.append(URLQueryItem(name: "api_key", value: apiKey))
        components.queryItems = items

        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
