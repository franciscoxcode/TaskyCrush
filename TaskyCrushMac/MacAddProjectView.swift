import SwiftUI

struct MacAddProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var showEmojiPicker = false

    var onCreate: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New project")
                .font(.title2)
                .fontWeight(.semibold)

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

                TextField("Project Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 220)
            }
            .padding(.horizontal, 6)

            HStack(spacing: 10) {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines), emoji)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate)
            }
        }
        .padding(20)
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
