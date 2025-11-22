import SwiftUI

struct MacAddProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var showEmojiPicker = false

    var onCreate: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New project")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button {
                    showEmojiPicker = true
                } label: {
                    Text(emoji.isEmpty ? "✨" : emoji)
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                TextField("Project name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal, 4)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Create") {
                    onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines), emoji)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showEmojiPicker) {
            MacEmojiPickerView { selected in
                emoji = selected
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !emoji.isEmpty
    }
}
