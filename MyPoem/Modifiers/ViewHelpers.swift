// MyPoem/Helpers/ViewHelpers.swift (New File)
// Or any other suitable location like MyPoem/Extensions/View+ReadSize.swift

import SwiftUI

// 1. Define the PreferenceKey
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        // No need to reduce if we only care about the last reported size.
        // If multiple views report a size, how they are combined depends on the hierarchy.
        // For this use case, we expect it on a specific view.
        value = nextValue()
    }
}

// 2. Create the View extension
extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}
