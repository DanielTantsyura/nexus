import Foundation
import Security

/// Helper class for Keychain operations
class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    /// Save a value to the Keychain
    /// - Parameters:
    ///   - value: The value to save
    ///   - key: The key to save it under
    func save(_ value: Any, key: String) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true) else {
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    /// Get a value from the Keychain
    /// - Parameter key: The key to retrieve
    /// - Returns: The saved value, or nil if not found
    func get(key: String) -> Any? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            guard let retrievedData = dataTypeRef as? Data else {
                return nil
            }
            
            // Use modern API for iOS 12.0+
            if #available(iOS 12.0, *) {
                return try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSString.self, NSNumber.self, NSArray.self, NSDictionary.self, NSDate.self], from: retrievedData)
            } else {
                // Fallback for older iOS versions
                return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(retrievedData)
            }
        }
        
        return nil
    }
    
    /// Delete a value from the Keychain
    /// - Parameter key: The key to delete
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
} 