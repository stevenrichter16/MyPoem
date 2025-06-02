//
//  PoemCreationStatusView.swift
//  MyPoem
//
//  Created by Steven Richter on 5/31/25.
//

import SwiftUI


struct PoemCreationStatusView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 16) {
            if appState.isCreatingPoem {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let poemType = appState.currentCreationType {
                    Text(appState.isCreatingPoem ? "Creating \(poemType.name)..." : "New \(poemType.name) Created!")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if appState.isCreatingPoem,
                       let creation = appState.poemCreation {
                        Text("Crafting your poem about \"\(creation.topic)\"")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            appState.isCreatingPoem ? Color.blue : Color.green,
                            appState.isCreatingPoem ? Color.blue.opacity(0.8) : Color.green.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.isCreatingPoem)
    }
}
