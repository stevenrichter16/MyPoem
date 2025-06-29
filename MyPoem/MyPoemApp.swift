// MyPoemApp.swift - Updated for CloudKit
import SwiftUI
import SwiftData
import CloudKit

@main
struct MyPoemApp: App {
    // Create model container with CloudKit support
    let modelContainer: ModelContainer
    
    // Configuration
    let configuration: AppConfiguration = DefaultConfiguration()
    
    // Create our observable services
    @State private var dataManager: DataManager
    @State private var appState = AppState()
    @State private var chatService: ChatService
    @State private var syncManager: CloudKitSyncManager
    
    init() {
        // Configure CloudKit-compatible model container
        do {
            let schema = Schema([
                RequestEnhanced.self,
                ResponseEnhanced.self,
                PoemGroup.self,
                PoemRevision.self,
                PoemNote.self,
                AudioNote.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none // Disable CloudKit sync
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        
        // Initialize services
        let context = modelContainer.mainContext
        
        // Configure context for CloudKit
        context.autosaveEnabled = true
        
        // Create sync manager first with configuration
        let sm = CloudKitSyncManager(modelContext: context, configuration: configuration)
        
        // Create data manager with sync support
        let dm = DataManager(modelContext: context, syncManager: sm)
        
        // Create app state
        let appState = AppState()
        
        // Create chat service with configuration
        let cs = ChatService(dataManager: dm, appState: appState, configuration: configuration)
        
        // Initialize state properties
        _syncManager = State(initialValue: sm)
        _dataManager = State(initialValue: dm)
        _appState = State(initialValue: appState)
        _chatService = State(initialValue: cs)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(dataManager)
                .environment(chatService)
                .environment(syncManager)
                .environment(\.configuration, configuration)
                .modelContainer(modelContainer)
                .onAppear {
                    setupCloudKit()
                    appState.prepareForLaunch()
                }
                .task {
                    // Check for existing data to migrate
                    await checkForDataMigration()
                }
        }
    }
    
    private func setupCloudKit() {
        // DISABLED: CloudKit completely
        return
        
        // Request CloudKit permissions if needed
        CKContainer.default().accountStatus { status, error in
            switch status {
            case .available:
                print("✅ iCloud is available")
            case .noAccount:
                print("⚠️ No iCloud account")
            case .restricted, .couldNotDetermine:
                print("⚠️ iCloud access restricted or undetermined")
            default:
                print("⚠️ Unknown iCloud status")
            }
        }
        
        // Setup push notifications for CloudKit sync
        setupCloudKitSubscriptions()
    }
    
    private func setupCloudKitSubscriptions() {
        let container = CKContainer.default()
        let privateDB = container.privateCloudDatabase
        
        // Create subscriptions for each record type
        let requestSubscription = CKQuerySubscription(
            recordType: "Request",
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        requestSubscription.notificationInfo = notificationInfo
        
        privateDB.save(requestSubscription) { _, error in
            if let error = error {
                print("Failed to create request subscription: \(error)")
            }
        }
        
        // Similar subscriptions for Response and PoemGroup...
    }
    
    private func checkForDataMigration() async {
        // Check if this is first launch with CloudKit
        let hasPerformedMigration = UserDefaults.standard.bool(forKey: "HasPerformedCloudKitMigration")
        
        if !hasPerformedMigration {
            // Mark all existing data for sync
            try? await dataManager.markAllForSync()
            UserDefaults.standard.set(true, forKey: "HasPerformedCloudKitMigration")
            
            // DISABLED: CloudKit sync
            // await syncManager.syncNow()
        }
    }
    
    private func clearAllDataForDebugging() async {
        do {
            // Fetch and delete all data
            let context = modelContainer.mainContext
            
            // Delete all responses
            let responses = try context.fetch(FetchDescriptor<ResponseEnhanced>())
            for response in responses {
                context.delete(response)
            }
            
            // Delete all requests
            let requests = try context.fetch(FetchDescriptor<RequestEnhanced>())
            for request in requests {
                context.delete(request)
            }
            
            // Delete all poem groups
            let groups = try context.fetch(FetchDescriptor<PoemGroup>())
            for group in groups {
                context.delete(group)
            }
            
            // Delete all revisions
            let revisions = try context.fetch(FetchDescriptor<PoemRevision>())
            for revision in revisions {
                context.delete(revision)
            }
            
            // Delete all notes
            let notes = try context.fetch(FetchDescriptor<PoemNote>())
            for note in notes {
                context.delete(note)
            }
            
            // Delete all audio notes
            let audioNotes = try context.fetch(FetchDescriptor<AudioNote>())
            for audioNote in audioNotes {
                // Delete audio file
                if let url = audioNote.audioFileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                context.delete(audioNote)
            }
            
            // Save the deletions
            try context.save()
            
            print("✅ Cleared all data: \(responses.count) responses, \(requests.count) requests, \(groups.count) groups, \(revisions.count) revisions, \(notes.count) notes, \(audioNotes.count) audio notes")
            
            // Also clear the migration flag
            UserDefaults.standard.set(false, forKey: "HasPerformedCloudKitMigration")
            
        } catch {
            print("❌ Failed to clear data: \(error)")
        }
    }
}

// MARK: - Main Content View with Sync Status

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(DataManager.self) private var dataManager
    @Environment(CloudKitSyncManager.self) private var syncManager
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main tab view
            MainTabView()
            
            // Sync status overlay
            VStack {
                HStack {
                    Spacer()
                    SyncStatusView()
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                }
                Spacer()
            }
            .ignoresSafeArea(.keyboard)
        }
        .alert("iCloud Not Available", isPresented: .constant(!syncManager.syncErrors.isEmpty && syncManager.syncErrors.contains { error in
            if case .noiCloudAccount = error { return true }
            return false
        })) {
            Button("OK") { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Sign in to iCloud in Settings to sync your poems across devices.")
        }
    }
}
