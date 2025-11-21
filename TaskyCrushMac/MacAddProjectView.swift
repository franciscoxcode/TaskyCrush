import SwiftUI

struct MacAddProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var showEmojiPicker = false

    var onCreate: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Project")) {
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
                    }
                }
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines), emoji)
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
            .sheet(isPresented: $showEmojiPicker) {
                MacEmojiPickerView { selected in
                    emoji = selected
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !emoji.isEmpty
    }
}
