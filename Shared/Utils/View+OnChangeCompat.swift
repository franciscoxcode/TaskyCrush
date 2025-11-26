import SwiftUI

extension View {
    // Two-parameter variant (preferred call site).
    @ViewBuilder
    func onChangeCompat<T: Equatable>(of value: T, perform: @escaping (_ oldValue: T, _ newValue: T) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { oldValue, newValue in
                perform(oldValue, newValue)
            }
        } else {
            self.onChange(of: value) { newValue in
                perform(newValue, newValue)
            }
        }
    }

    // One-parameter convenience (if callers want single `new` value).
    @ViewBuilder
    func onChangeCompat<T: Equatable>(of value: T, perform: @escaping (_ newValue: T) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in
                perform(newValue)
            }
        } else {
            self.onChange(of: value, perform: perform)
        }
    }
}
