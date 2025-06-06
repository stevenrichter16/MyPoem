import SwiftUI

struct ConfigurationDebugView: View {
    @Environment(\.configuration) private var config
    
    var body: some View {
        NavigationView {
            List {
                Section("OpenAI Configuration") {
                    LabeledContent("API Key", value: String(config.openAIAPIKey.prefix(8)) + "...")
                    LabeledContent("Endpoint", value: config.openAIEndpoint)
                    LabeledContent("Model", value: config.openAIModel)
                    LabeledContent("Max Tokens", value: "\(config.openAIMaxTokens)")
                    LabeledContent("Temperature", value: String(format: "%.1f", config.openAITemperature))
                }
                
                Section("CloudKit Configuration") {
                    LabeledContent("Container ID", value: config.cloudKitContainerIdentifier ?? "Default")
                    LabeledContent("Sync Batch Size", value: "\(config.syncBatchSize)")
                    LabeledContent("Sync Debounce", value: String(format: "%.1fs", config.syncDebounceInterval))
                    LabeledContent("Max Retries", value: "\(config.maxSyncRetries)")
                }
                
                Section("App Behavior") {
                    LabeledContent("Default Poem Type", value: config.defaultPoemType)
                    LabeledContent("Max Poem Length", value: "\(config.maxPoemLength)")
                    LabeledContent("Offline Mode", value: config.enableOfflineMode ? "Enabled" : "Disabled")
                    LabeledContent("Cache Duration", value: String(format: "%.0f min", config.cacheExpirationInterval / 60))
                }
                
                Section("Feature Flags") {
                    Toggle("Revision History", isOn: .constant(config.enableRevisionHistory))
                        .disabled(true)
                    Toggle("Poem Groups", isOn: .constant(config.enablePoemGroups))
                        .disabled(true)
                    Toggle("Debug Logging", isOn: .constant(config.enableDebugLogging))
                        .disabled(true)
                }
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ConfigurationDebugView()
        .environment(\.configuration, DefaultConfiguration())
}