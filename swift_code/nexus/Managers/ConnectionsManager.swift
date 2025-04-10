import SwiftUI
import Combine
import Foundation

class ConnectionsManager {
    private unowned let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    // MARK: - Fetch Connections
    func fetchUserConnections() {
        guard let userId = networkManager.userId else { return }
        fetchConnections(forUserId: userId)
    }

    func fetchConnections(forUserId userId: Int) {
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        guard let url = URL(string: "\(networkManager.baseURL)/people/\(userId)/connections") else {
            handleNetworkError(message: "Invalid URL", code: 400)
            return
        }
        
        let request = networkManager.createRequest(for: url)
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> [Connection] in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw self.createError(message: "Invalid response", code: 0)
                }
                
                // No content or not found means empty connections list
                if httpResponse.statusCode == 404 || httpResponse.statusCode == 204 || data.isEmpty {
                    return []
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw self.createError(message: "Server error: \(httpResponse.statusCode)", code: httpResponse.statusCode)
                }
                
                return self.parseConnectionsData(data)
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.networkManager.setLoading(false)
                    if case let .failure(error) = completion {
                        self.networkManager.setConnections([])
                        self.networkManager.setErrorMessage(error.localizedDescription)
                    }
                },
                receiveValue: { connections in
                    self.networkManager.setConnections(self.sortConnectionsByLastViewed(connections))
                    self.networkManager.signalRefresh(type: .connections)
                }
            )
            .store(in: &networkManager.cancellables)
    }
    
    // MARK: - Create Connection
    func createConnection(contactId: Int, description: String, notes: String? = nil, tags: [String]? = nil,
                          completion: @escaping (Result<Bool, Error>) -> Void) {
        // Validate user is logged in
        guard let userId = networkManager.userId else {
            completion(.failure(createError(message: "Not logged in", code: 401)))
            return
        }
        
        // Validate input parameters
        guard contactId > 0, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let errorMessage = contactId <= 0 ? "Invalid contact ID" : "Description cannot be empty"
            completion(.failure(createError(message: errorMessage, code: 400, domain: "ValidationError")))
            return
        }
        
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        guard let url = URL(string: "\(networkManager.baseURL)/connections") else {
            networkManager.setLoading(false)
            completion(.failure(createError(message: "Invalid URL", code: 400)))
            return
        }
        
        // Prepare request data
        let requestDict = prepareConnectionDict(userId: userId, contactId: contactId, 
                                              description: description, notes: notes, tags: tags)
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
            networkManager.setLoading(false)
            completion(.failure(createError(message: "Failed to encode connection data", code: 400)))
            return
        }
        
        let request = networkManager.createRequest(for: url, method: "POST", body: jsonData)
        
        sendConnectionRequest(request, expectedCode: 201, userId: userId, tags: tags, completion: completion)
    }
    
    // MARK: - Update Connection
    func updateConnection(contactId: Int, description: String? = nil, notes: String? = nil,
                          tags: [String]? = nil, updateTimestampOnly: Bool = false,
                          completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let userId = networkManager.userId else {
            completion(.failure(createError(message: "Not logged in", code: 401)))
            return
        }
        
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        guard let url = URL(string: "\(networkManager.baseURL)/connections") else {
            networkManager.setLoading(false)
            completion(.failure(createError(message: "Invalid URL", code: 400)))
            return
        }
        
        // Prepare request data
        var requestDict: [String: Any] = ["user_id": userId, "contact_id": contactId]
        
        if updateTimestampOnly {
            requestDict["update_timestamp_only"] = true
        } else {
            if let description = description { requestDict["relationship_type"] = description }
            if let notes = notes { requestDict["notes"] = notes }
            if let tags = tags { 
                // Always send tags array, even when empty
                // This allows explicitly clearing all tags
                requestDict["tags"] = tags
            }
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
            networkManager.setLoading(false)
            completion(.failure(createError(message: "Failed to encode connection data", code: 400)))
            return
        }
        
        let request = networkManager.createRequest(for: url, method: "PUT", body: jsonData)
        
        sendConnectionRequest(request, expectedCode: 200, userId: userId, tags: tags, completion: completion)
    }

    func updateConnectionTimestamp(contactId: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        updateConnection(contactId: contactId, updateTimestampOnly: true, completion: completion)
    }
    
    // MARK: - Remove Connection
    func removeConnection(contactId: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let userId = networkManager.userId else {
            completion(.failure(createError(message: "Not logged in", code: 401)))
            return
        }
        
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        guard let url = URL(string: "\(networkManager.baseURL)/connections") else {
            networkManager.setLoading(false)
            completion(.failure(createError(message: "Invalid URL", code: 400)))
            return
        }
        
        let requestDict = ["user_id": userId, "contact_id": contactId]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
            networkManager.setLoading(false)
            completion(.failure(createError(message: "Failed to encode connection data", code: 400)))
            return
        }
        
        let request = networkManager.createRequest(for: url, method: "DELETE", body: jsonData)
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw self.createError(message: "Invalid response", code: 0)
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw self.createError(message: "Server error: \(httpResponse.statusCode)", code: httpResponse.statusCode)
                }
                
                return true
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completionStatus in
                    self.networkManager.setLoading(false)
                    if case let .failure(error) = completionStatus {
                        self.networkManager.setErrorMessage(error.localizedDescription)
                        completion(.failure(error))
                    }
                },
                receiveValue: { _ in
                    // Filter out removed connection
                    let updated = self.networkManager.connections.filter { $0.id != contactId }
                    self.networkManager.setConnections(updated)
                    completion(.success(true))
                }
            )
            .store(in: &networkManager.cancellables)
    }
    
    func deleteContact(contactId: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        removeConnection(contactId: contactId, completion: completion)
    }
    
    // MARK: - Helper Methods
    
    /// Creates a standardized NSError with the given message and code
    private func createError(message: String, code: Int, domain: String = "NetworkError") -> NSError {
        return NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
    
    /// Handles network errors by setting loading state to false and providing error details
    private func handleNetworkError(message: String, code: Int) {
        networkManager.setLoading(false)
        networkManager.setConnections([])
        networkManager.setErrorMessage(message)
    }
    
    /// Extracts tags from various possible tag formats in connection data
    private func extractTags(from tagsValue: Any?) -> [String]? {
        guard let tagsValue = tagsValue else { return nil }
        
        // Handle array of strings
        if let tagsArray = tagsValue as? [String] {
            return tagsArray.filter { !$0.isEmpty }
        }
        
        // Handle comma-separated string
        if let tagsString = tagsValue as? String, !tagsString.isEmpty {
            return tagsString.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        // Handle any other string representation
        let stringValue = String(describing: tagsValue).trimmingCharacters(in: .whitespacesAndNewlines)
        if !stringValue.isEmpty, stringValue != "Optional(nil)" {
            return stringValue.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        return nil
    }
    
    /// Parses connection data from JSON response, handling tag extraction
    private func parseConnectionsData(_ data: Data) -> [Connection] {
        // Try standard decoding first
        if let connections = try? JSONDecoder().decode([Connection].self, from: data) {
            return connections
        }
        
        // Fall back to manual tag extraction if needed
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        return jsonArray.compactMap { connectionDict in
            let tags = extractTags(from: connectionDict["tags"])
            var mutableDict = connectionDict
            mutableDict.removeValue(forKey: "tags")
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: mutableDict),
                  var connection = try? JSONDecoder().decode(Connection.self, from: jsonData) else {
                return nil
            }
            
            connection.tags = tags
            return connection
        }
    }
    
    /// Sorts connections by last viewed date, most recent first
    private func sortConnectionsByLastViewed(_ connections: [Connection]) -> [Connection] {
        return connections.sorted { c1, c2 in
            guard let lv1 = c1.lastViewed else { return false }
            guard let lv2 = c2.lastViewed else { return true }
            return lv1 > lv2
        }
    }
    
    /// Prepares the dictionary for connection requests
    private func prepareConnectionDict(userId: Int, contactId: Int, description: String, 
                                      notes: String? = nil, tags: [String]? = nil) -> [String: Any] {
        var requestDict: [String: Any] = [
            "user_id": userId,
            "contact_id": contactId,
            "relationship_type": description
        ]
        
        if let notes = notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requestDict["notes"] = notes
        }
        
        if let tags = tags, !tags.isEmpty {
            let validTags = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !validTags.isEmpty {
                requestDict["tags"] = validTags
            }
        }
        
        return requestDict
    }
    
    /// Sends a connection request and handles the response
    private func sendConnectionRequest(_ request: URLRequest, expectedCode: Int, userId: Int, 
                                      tags: [String]?, completion: @escaping (Result<Bool, Error>) -> Void) {
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw self.createError(message: "Invalid response", code: 0)
                }
                
                guard httpResponse.statusCode == expectedCode else {
                    throw self.createError(message: "Server error: \(httpResponse.statusCode)", code: httpResponse.statusCode)
                }
                
                return true
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completionStatus in
                    self.networkManager.setLoading(false)
                    if case let .failure(error) = completionStatus {
                        self.networkManager.setErrorMessage(error.localizedDescription)
                        completion(.failure(error))
                    }
                },
                receiveValue: { _ in
                    self.fetchConnections(forUserId: userId)
                    if let tags = tags, !tags.isEmpty {
                        self.networkManager.fetchRecentTags()
                    }
                    completion(.success(true))
                }
            )
            .store(in: &networkManager.cancellables)
    }
} 