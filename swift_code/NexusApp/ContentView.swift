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
