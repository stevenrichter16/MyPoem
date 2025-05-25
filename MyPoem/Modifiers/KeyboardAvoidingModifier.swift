import SwiftUI
import Combine

struct KeyboardAdaptiveInputBar: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .animation(.spring(response: 0.75, dampingFraction: 0.8), value: keyboardHeight)
            .onAppear {
                setupKeyboardNotifications()
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
            }
    }
    
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self.keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.keyboardHeight = 0
        }
    }
}

extension View {
    func adaptToKeyboard() -> some View {
        self.modifier(KeyboardAdaptiveInputBar())
    }
}
