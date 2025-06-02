// MyPoem/Views/PoemDiffView.swift
import SwiftUI

struct PoemDiffView: View {
    let segments: [PoemDiff.DiffSegment]
    @Binding var showAdditions: Bool
    @Binding var showDeletions: Bool
    
    var body: some View {
        Text(attributedContent)
            .font(.body)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var attributedContent: AttributedString {
        var result = AttributedString()
        
        for segment in segments {
            var segmentString = AttributedString(segment.text)
            
            switch segment.type {
            case .unchanged:
                // No special formatting
                break
                
            case .added:
                if showAdditions {
                    segmentString.backgroundColor = Color.green.opacity(0.2)
                    segmentString.foregroundColor = Color.primary
                }
                
            case .deleted:
                if showDeletions {
                    segmentString.backgroundColor = Color.red.opacity(0.2)
                    segmentString.foregroundColor = Color.primary
                    segmentString.strikethroughStyle = Text.LineStyle(
                        pattern: .solid,
                        color: Color.red.opacity(0.5)
                    )
                }
            }
            
            result.append(segmentString)
        }
        
        return result
    }
}
