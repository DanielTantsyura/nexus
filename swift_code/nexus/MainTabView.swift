import SwiftUI
import Combine

/// Main tab view containing the primary application screens
struct MainTabView: View {
    // MARK: - Environment
    
    /// Reference to the app coordinator
    @EnvironmentObject var coordinator: AppCoordinator
    
    // MARK: - Properties
    
    @StateObject private var keyboardHandler = KeyboardHandler()
    
    // MARK: - View
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $coordinator.selectedTab) {
                // Network Tab
                NavigationStack(path: $coordinator.networkTabPath) {
                    NetworkView()
                        .navigationDestination(for: User.self) { user in
                            ContactView(user: user)
                        }
                }
                .tabItem {
                    Label("Network", systemImage: "person.3")
                }
                .tag(TabSelection.network)
                
                // Add New Tab - hidden tab item but visible when selected
                NavigationStack {
                    CreateContactView()
                }
                .tabItem { 
                    // Empty tab item that will be replaced by the floating button
                    Label("", systemImage: "")
                }
                .tag(TabSelection.addNew)
                
                // Profile Tab
                NavigationStack(path: $coordinator.profileTabPath) {
                    ProfileView()
                        .navigationDestination(for: ActiveScreen.self) { screen in
                            switch screen {
                            default:
                                EmptyView()
                            }
                        }
                }
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(TabSelection.profile)
            }
            .onChange(of: coordinator.selectedTab) { oldTab, newTab in
                // If navigating away from Network tab, check if we need to exit edit mode
                if oldTab == .network && coordinator.activeScreen == .contact {
                    // Reset the "StartContactInEditMode" flag to ensure we exit edit mode
                    UserDefaults.standard.set(false, forKey: "StartContactInEditMode")
                    // Post a notification that will be picked up by ContactView
                    NotificationCenter.default.post(name: NSNotification.Name("CancelContactEditing"), object: nil)
                }
                
                // Call coordinator's selectTab method to handle the tab change
                coordinator.selectTab(newTab)
            }
            
            // Only show add button if keyboard is not visible
            if !keyboardHandler.isVisible {
                AddButton(action: {
                    // Hide keyboard when switching tabs
                    hideKeyboard()
                    coordinator.selectedTab = .addNew
                })
                .offset(y: 8)
            }
        }
    }
    
    /// Hides the keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// A reusable add button component that can be used throughout the app
struct AddButton: View {
    var action: () -> Void
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: coordinator.selectedTab == .addNew ? 20 : 30, weight: .bold))
                Text("Add")
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .frame(width: coordinator.selectedTab == .addNew ? 70 : 100, height: coordinator.selectedTab == .addNew ? 70 : 100)
            .background(coordinator.selectedTab == .addNew ? Color.gray : Color.green)
            .clipShape(Capsule())
            .shadow(radius: 2)
        }
        .accessibilityLabel("Add new contact")
    }
}

/// A keyboard handler that can be reused across the app
class KeyboardHandler: ObservableObject {
    @Published var isVisible = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen to keyboard notifications
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] _ in
                self?.isVisible = true
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                self?.isVisible = false
            }
            .store(in: &cancellables)
    }
}

/// Main view model that serves as the entry point for the application
struct MainView: View {
    /// Reference to the app coordinator
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        Group {
            if coordinator.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environment(\.keyboardDismissMode, .automatic)
    }
}

/// Loading view displayed during data operations
struct LoadingOverlayView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.systemGray5))
            )
        }
    }
}

// MARK: - Environment Values

/// Environment key for controlling keyboard dismiss behavior
struct KeyboardDismissModeKey: EnvironmentKey {
    static let defaultValue: KeyboardDismissMode = .automatic
}

/// Mode for keyboard dismiss behavior
enum KeyboardDismissMode {
    case automatic
    case manual
}

extension EnvironmentValues {
    /// Controls how the keyboard is dismissed
    var keyboardDismissMode: KeyboardDismissMode {
        get { self[KeyboardDismissModeKey.self] }
        set { self[KeyboardDismissModeKey.self] = newValue }
    }
}

// MARK: - Navigation Extensions

extension View {
    /// Conditionally applies a navigation title
    /// - Parameters:
    ///   - title: The title to display
    ///   - displayMode: How to display the title
    /// - Returns: A view with the navigation title applied
    func conditionalNavigationTitle(_ title: String, displayMode: NavigationBarItem.TitleDisplayMode = .automatic) -> some View {
        self.navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
    }
    
    /// Adds a back button to the navigation bar
    /// - Parameter action: Action to perform when back is tapped
    /// - Returns: A view with the back button added
    func withBackButton(action: @escaping () -> Void) -> some View {
        self.navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: action) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
    }
}