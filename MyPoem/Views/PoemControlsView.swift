//
//  PoemControlsView.swift
//  MyPoem
//
//  Created by Steven Richter on 5/19/25.
//

import SwiftUI

struct PoemControlsView: View {
    @Binding var selectedPoemType: PoemType
    @Binding var selectedTemperature: Temperature
    
    var body: some View {
        HStack(spacing: 16) {
            PoemTypeSelector(selectedPoemType: $selectedPoemType)
            TemperatureSelector(selectedTemperature: $selectedTemperature)
        }
        .padding(.horizontal)
    }
}
