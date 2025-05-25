//
//  TemperatureSelector.swift
//  MyPoem
//
//  Created by Steven Richter on 5/19/25.
//

import SwiftUI  

struct TemperatureSelector: View {
    @Binding var selectedTemperature: Temperature
    
    var body: some View {
        Picker("Creativity", selection: $selectedTemperature) {
            ForEach(Temperature.all, id: \.id) { temp in
                Text(temp.textDescription)
                    .tag(temp)
            }
        }
        .pickerStyle(.segmented)
    }
}

