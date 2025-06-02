//
//  CreateView.swift
//  MyPoem
//
//  Created by Steven Richter on 5/31/25.
//

import SwiftUI


struct CreateView: View {
    @Environment(AppState.self) private var appState
    @Environment(DataManager.self) private var dataManager
    @Environment(ChatService.self) private var chatService
    
    @State private var selectedPoemType: PoemType = PoemType.all[0]
    @State private var selectedTemperature: Temperature = Temperature.all[0]
    @State private var showingComposer = false
    
    private var displayedRequests: [RequestEnhanced] {
        if let filter = appState.activeFilter {
            return dataManager.requests(for: filter)
        } else {
            return dataManager.sortedRequests
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Message history
                MessageHistoryView(requests: displayedRequests)
                    .padding(.bottom, 60)
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        FloatingActionButton(
                            isGenerating: chatService.isGenerating,
                            action: { showingComposer = true }
                        )
                        .padding(.trailing, 16)
                        .padding(.bottom, 100)
                    }
                }
                
                // Poem creation status overlay
                if appState.shouldShowCreationModal {
                    VStack {
                        PoemCreationStatusView()
                            .padding(.top, 50)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if dataManager.hasUnsyncedChanges {
                        Button(action: {
                            Task {
                                await dataManager.triggerSync()
                            }
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingComposer) {
                PoemComposerView(
                    selectedPoemType: $selectedPoemType,
                    selectedTemperature: $selectedTemperature,
                    onSubmit: { topic in
                        appState.startPoemCreation(
                            type: selectedPoemType,
                            topic: topic
                        )
                        showingComposer = false
                    }
                )
            }
        }
    }
}
