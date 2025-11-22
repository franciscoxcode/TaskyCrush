import SwiftUI

struct MacEditProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var emoji: String
    @State private var showEmojiPicker = false

    let project: MacProject
    var onSave: (String, String) -> Void
    var onDelete: () -> Void

    init(
        project: MacProject,
        onSave: @escaping (String, String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.project = project
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: project.name)
        _emoji = State(initialValue: project.emoji)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit project")
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
                    .frame(maxWidth: 330)
            }
            .padding(.horizontal, 6)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Text("Delete")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(trimmedName, trimmedEmoji)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .fixedSize(horizontal: true, vertical: false)
        .sheet(isPresented: $showEmojiPicker) {
            MacEmojiPickerView { selected in
                emoji = selected
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
