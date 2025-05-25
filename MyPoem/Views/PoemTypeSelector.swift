//
//  PoemTypeSelector.swift
//  MyPoem
//
//  Created by Steven Richter on 5/19/25.
//

import SwiftUI

struct PoemTypeSelector: View {
    @Binding var selectedPoemType: PoemType
    
    var body: some View {
        Menu {
            ForEach(PoemType.all, id: \.id) { type in
                Button(type.name) {
                    selectedPoemType = type
                }
            }
        } label: {
            HStack {
                Text(selectedPoemType.name)
                Image(systemName: "chevron.down")
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}
