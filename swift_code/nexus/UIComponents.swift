import SwiftUI

// MARK: - Button Styles

/// A style for primary action buttons
/// 
/// Use this style for the most important actions in each view
struct PrimaryButtonStyle: ButtonStyle {
    /// Creates a styled view from the button's label.
    /// - Parameter configuration: The button style configuration.
    /// - Returns: A styled button view.
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

/// A style for secondary action buttons
///
/// Use this style for less prominent or optional actions
struct SecondaryButtonStyle: ButtonStyle {
    /// Creates a styled view from the button's label.
    /// - Parameter configuration: The button style configuration.
    /// - Returns: A styled button view.
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

/// A circular avatar view displaying the user's initial
struct UserAvatar: View {
    /// The user to display the avatar for
    let user: User
    
    /// The size of the avatar (width and height)
    let size: CGFloat
    
    /// Creates a new user avatar with the specified size
    /// - Parameters:
    ///   - user: The user model to display
    ///   - size: The size of the avatar (default: 50)
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

/// A row displaying information with an icon, title, and value
struct InfoRow: View {
    /// SF Symbol name for the icon
    let icon: String
    
    /// Title/label for the information
    let title: String
    
    /// Value/content to display
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

/// A card view for grouping related content with a title
struct SectionCard<Content: View>: View {
    /// Title of the section
    let title: String
    
    /// Content view builder
    let content: Content
    
    /// Creates a new section card with title and content
    /// - Parameters:
    ///   - title: The title of the section
    ///   - content: A view builder closure that creates the content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !title.isEmpty {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)
            }
            
            content
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Status Views

/// A view displayed during loading operations
struct LoadingView: View {
    /// Message to display below the loading indicator
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

/// A view displayed when an error occurs
struct ErrorView: View {
    /// Error message to display
    let message: String
    
    /// Action to perform when retry is tapped
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

/// A view displayed when no content is available
struct EmptyStateView: View {
    /// SF Symbol name for the icon
    let icon: String
    
    /// Title of the empty state
    let title: String
    
    /// Message to display
    let message: String
    
    /// Title for the action button
    let buttonTitle: String
    
    /// Action to perform when the button is tapped
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.gray)
                .padding()
            
            Text(title)
                .font(.headline)
            
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.gray)
            
            Button(action: action) {
                Text(buttonTitle)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

/// A reusable flow layout for arranging views in a wrap-around manner
struct FlowLayout: Layout {
    /// Spacing between elements
    let spacing: CGFloat
    
    init(spacing: CGFloat = 10) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            // If this element doesn't fit on the current row, start a new row
            if rowWidth + subviewSize.width > containerWidth && rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = subviewSize.width
                rowHeight = subviewSize.height
            } else {
                // Add to the current row
                rowWidth += subviewSize.width + spacing
                rowHeight = max(rowHeight, subviewSize.height)
            }
        }
        
        // Add the height of the last row
        totalHeight += rowHeight
        
        return CGSize(width: containerWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowMinY: CGFloat = bounds.minY
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            // Check if this element needs to go on a new row
            if rowWidth + subviewSize.width > bounds.width && rowWidth > 0 {
                rowMinY += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            
            // Place the element
            let xPos = bounds.minX + rowWidth
            let yPos = rowMinY + (rowHeight - subviewSize.height) / 2
            
            subview.place(at: CGPoint(x: xPos, y: yPos), proposal: .unspecified)
            
            // Update tracking variables
            rowWidth += subviewSize.width + spacing
            rowHeight = max(rowHeight, subviewSize.height)
        }
    }
}

/// A tag badge view with optional remove button
struct TagBadge: View {
    /// The text of the tag
    let text: String
    
    /// Whether to show a remove button
    let showRemoveButton: Bool
    
    /// Action to perform when the remove button is tapped
    var onRemove: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .padding(.leading, 8)
            
            if showRemoveButton, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
                .padding(.trailing, 6)
            }
        }
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .cornerRadius(16)
    }
} 