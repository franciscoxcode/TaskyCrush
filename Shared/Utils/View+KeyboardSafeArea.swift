import SwiftUI

extension View {
    @ViewBuilder
    func ignoresKeyboardSafeArea() -> some View {
        #if os(iOS)
        self.ignoresSafeArea(.keyboard)
        #else
        self
        #endif
    }
}
