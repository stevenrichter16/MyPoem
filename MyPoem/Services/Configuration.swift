import Foundation
import SwiftUI

// MARK: - Configuration Protocol
protocol AppConfiguration {
    // OpenAI Configuration
    var openAIAPIKey: String { get }
    var openAIEndpoint: String { get }
    var openAIModel: String { get }
    var openAIMaxTokens: Int { get }
    var openAITemperature: Double { get }
    
    // CloudKit Configuration
    var cloudKitContainerIdentifier: String? { get }
    var syncBatchSize: Int { get }
    var syncDebounceInterval: TimeInterval { get }
    var maxSyncRetries: Int { get }
    
    // App Behavior
    var defaultPoemType: String { get }
    var maxPoemLength: Int { get }
    var enableOfflineMode: Bool { get }
    var cacheExpirationInterval: TimeInterval { get }
    
    // Feature Flags
    var enableRevisionHistory: Bool { get }
    var enablePoemGroups: Bool { get }
    var enableDebugLogging: Bool { get }
}

// MARK: - Default Configuration
struct DefaultConfiguration: AppConfiguration {
    // OpenAI Configuration
    var openAIAPIKey: String {
        // Load from Secrets.plist
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let apiKey = dict["OPENAI_API_KEY"] as? String else {
            fatalError("Missing OPENAI_API_KEY in Secrets.plist")
        }
        return apiKey
    }
    
    var openAIEndpoint: String {
        "https://api.openai.com/v1/chat/completions"
    }
    
    var openAIModel: String {
        "gpt-4o-mini"
    }
    
    var openAIMaxTokens: Int {
        1000
    }
    
    var openAITemperature: Double {
        0.7
    }
    
    // CloudKit Configuration
    var cloudKitContainerIdentifier: String? {
        nil // Uses default container
    }
    
    var syncBatchSize: Int {
        50
    }
    
    var syncDebounceInterval: TimeInterval {
        2.0
    }
    
    var maxSyncRetries: Int {
        3
    }
    
    // App Behavior
    var defaultPoemType: String {
        "Haiku"
    }
    
    var maxPoemLength: Int {
        5000
    }
    
    var enableOfflineMode: Bool {
        true
    }
    
    var cacheExpirationInterval: TimeInterval {
        3600 // 1 hour
    }
    
    // Feature Flags
    var enableRevisionHistory: Bool {
        true
    }
    
    var enablePoemGroups: Bool {
        true
    }
    
    var enableDebugLogging: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}


// MARK: - Environment Key
private struct ConfigurationKey: EnvironmentKey {
    static let defaultValue: AppConfiguration = DefaultConfiguration()
}

extension EnvironmentValues {
    var configuration: AppConfiguration {
        get { self[ConfigurationKey.self] }
        set { self[ConfigurationKey.self] = newValue }
    }
}

// MARK: - View Extension
extension View {
    func configuration(_ config: AppConfiguration) -> some View {
        environment(\.configuration, config)
    }
}