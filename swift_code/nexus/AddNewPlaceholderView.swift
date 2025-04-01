import SwiftUI

/// Placeholder view for the Add New functionality
struct AddNewPlaceholderView: View {
    // MARK: - Properties
    
    @EnvironmentObject private var coordinator: AppCoordinator
    
    // MARK: - View Body
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)
            
            Text("Add New Content")
                .font(.title)
                .fontWeight(.bold)
            
            Text("This feature is coming soon!")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("A coworker is building this functionality")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 10)
        }
        .padding()
        .navigationTitle("Add New")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            coordinator.activeScreen = .addNew
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationView {
        AddNewPlaceholderView()
            .environmentObject(AppCoordinator())
    }
} 