import SwiftUI

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - UI Components

struct UserAvatar: View {
    let user: User
    let size: CGFloat
    
    init(user: User, size: CGFloat = 50) {
        self.user = user
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Text(String(user.fullName.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.blue)
            )
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(value)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 4)
            
            content
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Loading States

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text(message)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
                .padding()
            
            Text("Error")
                .font(.headline)
                .foregroundColor(.red)
            
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Retry") {
                retryAction()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.7))
                .padding()
            
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(message)
                .foregroundColor(.gray)
            
            Button(buttonTitle) {
                action()
            }
            .buttonStyle(PrimaryButtonStyle())
            
            Spacer()
        }
        .padding()
    }
} 