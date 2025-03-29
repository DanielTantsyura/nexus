#!/bin/bash

# Create a new directory for our clean project
mkdir -p swift_code/NexusApp

# Create the basic Swift files
cat > swift_code/NexusApp/NexusApp.swift << 'EOL'
import SwiftUI

@main
struct NexusApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
EOL

cat > swift_code/NexusApp/ContentView.swift << 'EOL'
import SwiftUI

struct ContentView: View {
    @StateObject private var networkManager = NetworkManager()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button(action: {
                        networkManager.searchUsers(term: searchText)
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.trailing)
                }
                
                if networkManager.isLoading {
                    ProgressView()
                        .padding()
                } else if let errorMessage = networkManager.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    List(networkManager.users) { user in
                        NavigationLink(destination: UserDetailView(user: user, networkManager: networkManager)) {
                            VStack(alignment: .leading) {
                                Text(user.fullName)
                                    .font(.headline)
                                Text(user.university)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nexus Network")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        networkManager.fetchUsers()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            networkManager.fetchUsers()
        }
    }
}

struct UserDetailView: View {
    let user: User
    @ObservedObject var networkManager: NetworkManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // User info section
                VStack(alignment: .leading, spacing: 8) {
                    Text(user.fullName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(user.university)
                        .font(.title3)
                        .foregroundColor(.gray)
                    
                    Text(user.location)
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Contact info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact Information")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "envelope")
                        Text(user.email)
                    }
                    
                    HStack {
                        Image(systemName: "phone")
                        Text(user.phoneNumber)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Connections section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connections")
                        .font(.headline)
                    
                    if networkManager.connections.isEmpty {
                        Text("No connections found")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(networkManager.connections) { connection in
                            HStack {
                                Text(connection.fullName)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(connection.relationshipDescription)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Profile")
        .onAppear {
            networkManager.getConnections(userId: user.id)
        }
    }
}
EOL

cat > swift_code/NexusApp/NetworkManager.swift << 'EOL'
import SwiftUI
import Combine

// MARK: - Models
struct User: Identifiable, Codable {
    var id: Int
    var username: String
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String
    var location: String
    var university: String
    var fieldOfInterest: String
    var highSchool: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phoneNumber = "phone_number"
        case location
        case university
        case fieldOfInterest = "field_of_interest"
        case highSchool = "high_school"
    }
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}

struct Connection: Identifiable, Codable {
    var id: Int
    var username: String
    var firstName: String
    var lastName: String
    var relationshipDescription: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case relationshipDescription = "relationship_description"
    }
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}

// MARK: - Network Manager (combines ViewModel and Service)
class NetworkManager: ObservableObject {
    @Published var users: [User] = []
    @Published var selectedUser: User?
    @Published var connections: [Connection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let baseURL = "http://localhost:5000"
    
    // MARK: - API Methods
    func fetchUsers() {
        isLoading = true
        errorMessage = nil
        
        fetchData("/users", type: [User].self) { [weak self] result in
            self?.isLoading = false
            
            switch result {
            case .success(let users):
                self?.users = users
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
            }
        }
    }
    
    func searchUsers(term: String) {
        guard !term.isEmpty else {
            fetchUsers()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        guard let encodedTerm = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            errorMessage = "Invalid search term"
            isLoading = false
            return
        }
        
        fetchData("/users/search?term=\(encodedTerm)", type: [User].self) { [weak self] result in
            self?.isLoading = false
            
            switch result {
            case .success(let users):
                self?.users = users
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
            }
        }
    }
    
    func getUser(username: String) {
        isLoading = true
        errorMessage = nil
        
        fetchData("/users/\(username)", type: User.self) { [weak self] result in
            self?.isLoading = false
            
            switch result {
            case .success(let user):
                self?.selectedUser = user
                if let userId = user.id as? Int {
                    self?.getConnections(userId: userId)
                }
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
            }
        }
    }
    
    func getConnections(userId: Int) {
        fetchData("/users/\(userId)/connections", type: [Connection].self) { [weak self] result in
            switch result {
            case .success(let connections):
                self?.connections = connections
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Helper Methods
    private func fetchData<T: Decodable>(_ endpoint: String, type: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(URLError(.zeroByteResource)))
                    return
                }
                
                do {
                    let decodedData = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decodedData))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
EOL

# Create Info.plist for network access
cat > swift_code/NexusApp/Info.plist << 'EOL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>localhost</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
EOL

# Create Assets folder structure
mkdir -p swift_code/NexusApp/Assets.xcassets/AppIcon.appiconset
mkdir -p swift_code/NexusApp/Assets.xcassets/AccentColor.colorset

# Create Assets catalog contents
cat > swift_code/NexusApp/Assets.xcassets/Contents.json << 'EOL'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOL

cat > swift_code/NexusApp/Assets.xcassets/AppIcon.appiconset/Contents.json << 'EOL'
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOL

cat > swift_code/NexusApp/Assets.xcassets/AccentColor.colorset/Contents.json << 'EOL'
{
  "colors" : [
    {
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOL

# Update README
cat > swift_code/README.md << 'EOL'
# Nexus iOS App

A Swift/SwiftUI iOS application that connects to the Nexus database through a REST API.

## Project Structure

The project contains only essential files:

- **NexusApp.swift** - Entry point for the SwiftUI application
- **ContentView.swift** - Main UI components and user interface
- **NetworkManager.swift** - Data models and API communication
- **Info.plist** - App configuration and security settings
- **Assets.xcassets/** - Required for app icons

## How to Set Up

1. Open Xcode
2. Select "Open a project or file"
3. Navigate to the NexusApp folder and select it

## Backend Connection

This app connects to a Python Flask API that interfaces with the PostgreSQL database. The API needs to be running at `http://localhost:5000` for the app to function.

## How to Run

1. Start the backend API:
   ```
   python api.py
   ```

2. Run the app in Xcode using the play button

## Features

- View all users in the Nexus database
- Search for users by name, location, or other attributes
- View detailed user profiles including contact information
- See user connections and relationship descriptions
EOL

echo "Swift project files created in swift_code/NexusApp"
echo "To create the Xcode project, open Xcode and create a new iOS app project in the NexusApp directory"
echo "Choose File > New > Project > iOS > App and select swift_code/NexusApp as the location" 