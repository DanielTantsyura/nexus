import SwiftUI
import Combine
import Foundation

class TagsManager {
    private unowned let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func fetchRecentTags() {
        guard let userId = networkManager.userId else { return }
        print("Fetching recent tags for user ID: \(userId)")
        
        guard let url = URL(string: "\(networkManager.baseURL)/people/\(userId)/recent-tags") else {
            print("Invalid URL for recent tags")
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching recent tags: \(error.localizedDescription)")
                    self.networkManager.setRecentTags([])
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 404 {
                        print("Recent tags not found for user ID: \(userId)")
                        self.networkManager.setRecentTags([])
                        return
                    }
                    if !(200...299).contains(httpResponse.statusCode) {
                        print("Server error: \(httpResponse.statusCode) while fetching tags")
                        self.networkManager.setRecentTags([])
                        return
                    }
                }
                guard let data = data else {
                    print("No data for recent tags")
                    self.networkManager.setRecentTags([])
                    return
                }
                
                do {
                    // Attempt decode as [String]
                    if let tags = try? JSONDecoder().decode([String].self, from: data) {
                        self.networkManager.setRecentTags(tags)
                        return
                    }
                    // Attempt decode as a String and split
                    if let tagsString = try? JSONDecoder().decode(String.self, from: data),
                       !tagsString.isEmpty {
                        let arr = tagsString.split(separator: ",").map { String($0) }
                        self.networkManager.setRecentTags(arr)
                        return
                    }
                    // Attempt JSON object approach
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let tagsValue = json["recent_tags"] {
                        if let arr = tagsValue as? [String] {
                            self.networkManager.setRecentTags(arr)
                        } else if let str = tagsValue as? String, !str.isEmpty {
                            let arr = str.split(separator: ",").map { String($0) }
                            self.networkManager.setRecentTags(arr)
                        } else {
                            self.networkManager.setRecentTags([])
                        }
                    } else {
                        self.networkManager.setRecentTags([])
                    }
                } catch {
                    print("Failed decoding tags: \(error.localizedDescription)")
                    self.networkManager.setRecentTags([])
                }
            }
        }.resume()
    }
    
    func fetchUserRecentTags(completion: @escaping (Result<[String], Error>) -> Void) {
        guard let userId = networkManager.userId else {
            let err = NSError(domain: "NetworkManager", code: 401,
                              userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
            completion(.failure(err))
            return
        }
        
        guard let url = URL(string: "\(networkManager.baseURL)/people/\(userId)/recent-tags") else {
            networkManager.setErrorMessage("Invalid URL")
            let err = NSError(domain: "NetworkManager", code: 400,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            completion(.failure(err))
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.networkManager.setErrorMessage(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let err = NSError(domain: "NetworkManager", code: httpResponse.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    self.networkManager.setErrorMessage("Server error: \(httpResponse.statusCode)")
                    completion(.failure(err))
                    return
                }
                guard let data = data else {
                    let err = NSError(domain: "NetworkManager", code: 0,
                                      userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    self.networkManager.setErrorMessage("No data received")
                    completion(.failure(err))
                    return
                }
                
                do {
                    // Try array
                    if let tags = try? JSONDecoder().decode([String].self, from: data) {
                        self.networkManager.setRecentTags(tags)
                        completion(.success(tags))
                        return
                    }
                    // Try string
                    if let tagsString = try? JSONDecoder().decode(String.self, from: data),
                       !tagsString.isEmpty {
                        let arr = tagsString.split(separator: ",").map { String($0) }
                        self.networkManager.setRecentTags(arr)
                        completion(.success(arr))
                        return
                    }
                    // Try JSON object
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let tagsValue = json["recent_tags"] {
                        if let arr = tagsValue as? [String] {
                            self.networkManager.setRecentTags(arr)
                            completion(.success(arr))
                            return
                        } else if let str = tagsValue as? String, !str.isEmpty {
                            let arr = str.split(separator: ",").map { String($0) }
                            self.networkManager.setRecentTags(arr)
                            completion(.success(arr))
                            return
                        }
                    }
                    // If all fails
                    self.networkManager.setRecentTags([])
                    completion(.success([]))
                } catch {
                    self.networkManager.setRecentTags([])
                    print("Error decoding tags: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }.resume()
    }
} 