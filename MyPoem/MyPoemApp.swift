// MyPoemApp.swift - Updated for CloudKit
import SwiftUI
import SwiftData
import CloudKit

@main
struct MyPoemApp: App {
    // Create model container with CloudKit support
    let modelContainer: ModelContainer
    
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
                PoemRevision.self // Add this
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic // Enable CloudKit sync
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
        
        // Create sync manager first
        let sm = CloudKitSyncManager(modelContext: context)
        
        // Create data manager with sync support
        let dm = DataManager(modelContext: context, syncManager: sm)
        
        // Create app state
        let appState = AppState()
        
        // Create chat service
        let cs = ChatService(dataManager: dm, appState: appState)
        
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
            
            // Trigger initial sync
            await syncManager.syncNow()
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
