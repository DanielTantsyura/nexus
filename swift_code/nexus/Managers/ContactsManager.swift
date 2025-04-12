import SwiftUI
import Combine
import Foundation

class ContactsManager {
    private unowned let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    // MARK: - Current User
    func fetchCurrentUser() {
        guard let userId = networkManager.userId else { return }
        print("Fetching current user with ID: \(userId)")
        
        guard let url = URL(string: "\(networkManager.baseURL)/people/\(userId)") else {
            print("Invalid URL for current user")
            return
        }
        
        let request = networkManager.createRequest(for: url)
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> User in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                if httpResponse.statusCode == 401 {
                    // Session expired
                    self.networkManager.authManager.handleSessionExpiration()
                    throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Session expired"])
                }
                guard 200...299 ~= httpResponse.statusCode else {
                    if httpResponse.statusCode == 404 {
                        // We'll handle below
                        throw NSError(domain: "NetworkError", code: 404, userInfo: nil)
                    }
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                }
                return try JSONDecoder().decode(User.self, from: data)
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // If 404, attempt the "all users" approach
                        let nsError = error as NSError
                        if nsError.code == 404 {
                            print("User not found by ID, searching all users for ID \(userId)")
                            self.findUserInAllUsers(userId)
                        } else {
                            print("Failed to fetch user: \(error.localizedDescription)")
                        }
                    }
                },
                receiveValue: { user in
                    print("Successfully fetched user: \(user.id)")
                    self.networkManager.setCurrentUser(user)
                    self.networkManager.setCurrentUserLoaded(true)
                    self.networkManager.signalRefresh(type: .currentUser)
                    // Also fetch connections
                    self.networkManager.fetchConnections(forUserId: user.id)
                }
            )
            .store(in: &networkManager.cancellables)
    }
    
    // If direct fetch fails, try the big users list
    func findUserInAllUsers(_ targetUserId: Int) {
        if !networkManager.users.isEmpty {
            if let foundUser = networkManager.users.first(where: { $0.id == targetUserId }) {
                print("Found user \(targetUserId) in existing users list")
                networkManager.setCurrentUser(foundUser)
                networkManager.fetchConnections(forUserId: targetUserId)
                return
            }
        }
        // Otherwise fetch everyone
        print("Fetching all users to find user ID: \(targetUserId)")
        
        guard let url = URL(string: "\(networkManager.baseURL)/people") else {
            print("Invalid URL for fetching all users")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching all users: \(error.localizedDescription)")
                    return
                }
                guard let data = data else {
                    print("No data for all users")
                    return
                }
                do {
                    let allUsers = try JSONDecoder().decode([User].self, from: data)
                    self.networkManager.setUsers(allUsers)
                    
                    if let foundUser = allUsers.first(where: { $0.id == targetUserId }) {
                        print("Found user \(targetUserId) in fetched users list")
                        self.networkManager.setCurrentUser(foundUser)
                        self.networkManager.fetchConnections(forUserId: targetUserId)
                    } else {
                        print("User \(targetUserId) not found, creating minimal user")
                        let minimalUser = User(id: targetUserId,
                                               username: nil,
                                               firstName: "User",
                                               lastName: "\(targetUserId)",
                                               email: nil,
                                               phoneNumber: nil,
                                               location: nil,
                                               university: nil,
                                               fieldOfInterest: nil,
                                               highSchool: nil,
                                               birthday: nil,
                                               createdAt: nil,
                                               currentCompany: nil,
                                               gender: nil,
                                               ethnicity: nil,
                                               uniMajor: nil,
                                               jobTitle: nil,
                                               lastLogin: nil,
                                               profileImageUrl: nil,
                                               linkedinUrl: nil,
                                               recentTags: nil)
                        self.networkManager.setCurrentUser(minimalUser)
                        self.networkManager.fetchConnections(forUserId: targetUserId)
                    }
                } catch {
                    print("Failed to decode all users: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    // MARK: - Fetch All Users
    func fetchAllUsers() {
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        guard let url = URL(string: "\(networkManager.baseURL)/people") else {
            networkManager.setLoading(false)
            networkManager.setErrorMessage("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.networkManager.setLoading(false)
                if let error = error {
                    self.networkManager.setErrorMessage("Network error: \(error.localizedDescription)")
                    return
                }
                guard let data = data else {
                    self.networkManager.setErrorMessage("No data received")
                    return
                }
                do {
                    let users = try JSONDecoder().decode([User].self, from: data)
                    self.networkManager.setUsers(users)
                } catch {
                    self.networkManager.setErrorMessage("Failed to decode users: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // MARK: - Fetch a user
    func fetchUser(withId userId: Int, retryCount: Int = 0, completion: @escaping (Result<User, Error>) -> Void) {
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        guard let url = URL(string: "\(networkManager.baseURL)/people/\(userId)") else {
            networkManager.setLoading(false)
            let err = NSError(domain: "NetworkError", code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            completion(.failure(err))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.networkManager.setLoading(false)
                if let error = error {
                    if retryCount > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.fetchUser(withId: userId, retryCount: retryCount - 1, completion: completion)
                        }
                    } else {
                        self.networkManager.setErrorMessage("Network error: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    let err = NSError(domain: "NetworkError", code: 0,
                                      userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    self.networkManager.setErrorMessage("Invalid response")
                    completion(.failure(err))
                    return
                }
                if httpResponse.statusCode == 404 {
                    let err = NSError(domain: "NetworkError", code: 404,
                                      userInfo: [NSLocalizedDescriptionKey: "User not found"])
                    self.networkManager.setErrorMessage("User not found")
                    completion(.failure(err))
                    return
                }
                if !(200...299).contains(httpResponse.statusCode) {
                    let err = NSError(domain: "NetworkError", code: httpResponse.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    self.networkManager.setErrorMessage("Server error: \(httpResponse.statusCode)")
                    completion(.failure(err))
                    return
                }
                guard let data = data else {
                    let err = NSError(domain: "NetworkError", code: 0,
                                      userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    self.networkManager.setErrorMessage("No data received")
                    completion(.failure(err))
                    return
                }
                do {
                    let user = try JSONDecoder().decode(User.self, from: data)
                    completion(.success(user))
                } catch {
                    if retryCount > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.fetchUser(withId: userId, retryCount: retryCount - 1, completion: completion)
                        }
                    } else {
                        self.networkManager.setErrorMessage("Failed to decode user: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Fetch user by username
    func fetchUserByUsername(_ username: String, completion: @escaping (Result<User, Error>) -> Void) {
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        guard let url = URL(string: "\(networkManager.baseURL)/people/\(username)") else {
            networkManager.setLoading(false)
            let err = NSError(domain: "NetworkError", code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            completion(.failure(err))
            return
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let currentUserId = networkManager.userId {
            let queryItem = URLQueryItem(name: "viewing_user_id", value: "\(currentUserId)")
            components?.queryItems = [queryItem]
        }
        
        guard let finalUrl = components?.url else {
            networkManager.setLoading(false)
            let err = NSError(domain: "NetworkError", code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid URL components"])
            completion(.failure(err))
            return
        }
        
        URLSession.shared.dataTask(with: finalUrl) { data, response, error in
            DispatchQueue.main.async {
                self.networkManager.setLoading(false)
                
                if let error = error {
                    self.networkManager.setErrorMessage("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    let err = NSError(domain: "NetworkError", code: 0,
                                      userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    self.networkManager.setErrorMessage("Invalid response")
                    completion(.failure(err))
                    return
                }
                if httpResponse.statusCode == 404 {
                    let err = NSError(domain: "NetworkError", code: 404,
                                      userInfo: [NSLocalizedDescriptionKey: "User not found"])
                    self.networkManager.setErrorMessage("User not found")
                    completion(.failure(err))
                    return
                }
                if httpResponse.statusCode != 200 {
                    let err = NSError(domain: "NetworkError", code: httpResponse.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    self.networkManager.setErrorMessage("Server error: \(httpResponse.statusCode)")
                    completion(.failure(err))
                    return
                }
                guard let data = data else {
                    let err = NSError(domain: "NetworkError", code: 0,
                                      userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    self.networkManager.setErrorMessage("No data received")
                    completion(.failure(err))
                    return
                }
                do {
                    let user = try JSONDecoder().decode(User.self, from: data)
                    completion(.success(user))
                } catch {
                    self.networkManager.setErrorMessage("Failed to decode user: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Search
    func searchUsers(term: String) {
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        guard let baseSearchUrl = URL(string: "\(networkManager.baseURL)/people/search") else {
            networkManager.setLoading(false)
            networkManager.setErrorMessage("Invalid URL")
            return
        }
        
        var components = URLComponents(url: baseSearchUrl, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "term", value: term)]
        
        guard let url = components?.url else {
            networkManager.setLoading(false)
            networkManager.setErrorMessage("Invalid search term")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.networkManager.setLoading(false)
                if let error = error {
                    self.networkManager.setErrorMessage("Network error: \(error.localizedDescription)")
                    return
                }
                guard let data = data else {
                    self.networkManager.setErrorMessage("No data received")
                    return
                }
                do {
                    let users = try JSONDecoder().decode([User].self, from: data)
                    self.networkManager.setUsers(users)
                } catch {
                    self.networkManager.setErrorMessage("Failed to decode search results: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    // MARK: - Create Contact from text
    func createContact(fromText text: String, tags: [String]? = nil,
                       completion: @escaping (Result<Int, Error>) -> Void) {
        guard let userId = networkManager.userId else {
            let err = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
            completion(.failure(err))
            return
        }
        
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        guard let url = URL(string: "\(networkManager.baseURL)/contacts/create") else {
            networkManager.setLoading(false)
            networkManager.setErrorMessage("Invalid URL")
            let err = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            completion(.failure(err))
            return
        }
        
        var requestDict: [String: Any] = [
            "contact_text": text,
            "user_id": userId
        ]
        if let tags = tags, !tags.isEmpty {
            let nonEmptyTags = tags.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !nonEmptyTags.isEmpty {
                requestDict["tags"] = nonEmptyTags
            }
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
            networkManager.setLoading(false)
            networkManager.setErrorMessage("Failed to encode contact data")
            let err = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode contact data"])
            completion(.failure(err))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.networkManager.setLoading(false)
                
                if let error = error {
                    self.networkManager.setErrorMessage("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let err = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    self.networkManager.setErrorMessage("Invalid response")
                    completion(.failure(err))
                    return
                }
                
                if httpResponse.statusCode != 201 {
                    let err = NSError(domain: "NetworkError", code: httpResponse.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    self.networkManager.setErrorMessage("Server error: \(httpResponse.statusCode)")
                    completion(.failure(err))
                    return
                }
                
                guard let data = data else {
                    let err = NSError(domain: "NetworkError", code: 0,
                                      userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    self.networkManager.setErrorMessage("No data received")
                    completion(.failure(err))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let newContactUserId = json?["user_id"] as? Int {
                        if let tags = tags, !tags.isEmpty {
                            self.networkManager.fetchRecentTags()
                        }
                        self.networkManager.fetchConnections(forUserId: userId)
                        completion(.success(newContactUserId))
                    } else {
                        let err = NSError(domain: "NetworkError", code: 0,
                                          userInfo: [NSLocalizedDescriptionKey: "Missing user_id in response"])
                        self.networkManager.setErrorMessage("Missing user_id in response")
                        completion(.failure(err))
                    }
                } catch {
                    self.networkManager.setErrorMessage("Failed to parse response: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Update a User
    func updateUser(userId: Int, userData: [String: Any], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(networkManager.baseURL)/people/\(userId)") else {
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            networkManager.setErrorMessage("Invalid URL")
            completion(.failure(error))
            return
        }
        
        networkManager.setLoading(true)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: userData)
            request.httpBody = jsonData
        } catch {
            networkManager.setLoading(false)
            networkManager.setErrorMessage("Failed to encode user data: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                self.networkManager.setLoading(false)
                if let error = error {
                    self.networkManager.setErrorMessage("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        if userId == self.networkManager.userId {
                            self.fetchCurrentUser()
                            self.networkManager.signalRefresh(type: .profile)
                        }
                        completion(.success(true))
                    } else {
                        let serverError = NSError(domain: "NetworkError", code: httpResponse.statusCode, 
                                               userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                        self.networkManager.setErrorMessage("Server error: \(httpResponse.statusCode)")
                        completion(.failure(serverError))
                    }
                } else {
                    let responseError = NSError(domain: "NetworkError", code: 0, 
                                             userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    self.networkManager.setErrorMessage("Invalid response")
                    completion(.failure(responseError))
                }
            }
        }.resume()
    }
    
    func updateUser(_ user: User, completion: @escaping (Result<Bool, Error>) -> Void) {
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        guard let url = URL(string: "\(networkManager.baseURL)/people/\(user.id)") else {
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            networkManager.setLoading(false)
            networkManager.setErrorMessage("Invalid URL")
            completion(.failure(error))
            return
        }
        
        // Build minimal dictionary of updated fields
        var userDict: [String: Any] = [:]
        if let firstName = user.firstName { userDict["first_name"] = firstName }
        if let lastName = user.lastName { userDict["last_name"] = lastName }
        if let email = user.email { userDict["email"] = email }
        if let phoneNumber = user.phoneNumber { userDict["phone_number"] = phoneNumber }
        if let location = user.location { userDict["location"] = location }
        if let university = user.university { userDict["university"] = university }
        if let fieldOfInterest = user.fieldOfInterest { userDict["interests"] = fieldOfInterest }
        if let highSchool = user.highSchool { userDict["high_school"] = highSchool }
        if let birthday = user.birthday { userDict["birthday"] = birthday }
        if let currentCompany = user.currentCompany { userDict["current_company"] = currentCompany }
        if let gender = user.gender { userDict["gender"] = gender }
        if let ethnicity = user.ethnicity { userDict["ethnicity"] = ethnicity }
        if let uniMajor = user.uniMajor { userDict["uni_major"] = uniMajor }
        if let jobTitle = user.jobTitle { userDict["job_title"] = jobTitle }
        if let profileImageUrl = user.profileImageUrl { userDict["profile_image_url"] = profileImageUrl }
        if let linkedinUrl = user.linkedinUrl { userDict["linkedin_url"] = linkedinUrl }
        if let recentTags = user.recentTags {
            userDict["recent_tags"] = recentTags.joined(separator: ",")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: userDict) else {
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode user data"])
            networkManager.setLoading(false)
            networkManager.setErrorMessage("Failed to encode user data")
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                self.networkManager.setLoading(false)
                if let error = error {
                    self.networkManager.setErrorMessage("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    let responseError = NSError(domain: "NetworkError", code: 0, 
                                             userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    self.networkManager.setErrorMessage("Invalid response")
                    completion(.failure(responseError))
                    return
                }
                if !(200...299).contains(httpResponse.statusCode) {
                    let serverError = NSError(domain: "NetworkError", code: httpResponse.statusCode, 
                                           userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    self.networkManager.setErrorMessage("Server error: \(httpResponse.statusCode)")
                    completion(.failure(serverError))
                    return
                }
                if user.id == self.networkManager.userId {
                    self.networkManager.setCurrentUser(user)
                    self.fetchCurrentUser() // Refresh from server
                }
                completion(.success(true))
            }
        }.resume()
    }
} 