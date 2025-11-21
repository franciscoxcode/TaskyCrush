import SwiftUI

struct TaskNoteView: View {
    enum LayoutStyle {
        case sheet
        case sidebar
    }

    let taskId: UUID
    let taskTitle: String
    let initialMarkdown: String
    var autoSaveIntervalSeconds: TimeInterval = 3
    var layoutStyle: LayoutStyle
    // Callbacks
    var onSave: (_ text: String) -> Void
    var onAutoSave: (_ text: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @StateObject private var editorController = MarkdownEditorController()
    @State private var showTokens: Bool = true
    @State private var lastSavedText: String
    @State private var lastSavedAt: Date? = nil
    @State private var isSaving: Bool = false

    init(taskId: UUID, taskTitle: String, initialMarkdown: String, autoSaveIntervalSeconds: TimeInterval = 8, layoutStyle: LayoutStyle = .sheet, onSave: @escaping (_ text: String) -> Void, onAutoSave: @escaping (_ text: String) -> Void) {
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.initialMarkdown = initialMarkdown
        self.autoSaveIntervalSeconds = autoSaveIntervalSeconds
        self.layoutStyle = layoutStyle
        self.onSave = onSave
        self.onAutoSave = onAutoSave
        _text = State(initialValue: initialMarkdown)
        _lastSavedText = State(initialValue: initialMarkdown)
    }

    var body: some View {
        Group {
            if layoutStyle == .sheet {
                NavigationStack {
                    editorStack
                        .navigationTitle(taskTitle.isEmpty ? "Note" : taskTitle)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") { saveAndClose() }
                                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && initialMarkdown.isEmpty)
                            }
                        }
                }
            } else {
                editorStack
            }
        }
    }

    private var editorStack: some View {
        VStack(spacing: 0) {
            // Inline editor with placeholder
            ZStack(alignment: .topLeading) {
                MarkdownTextView(text: $text, controller: editorController)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .ignoresSafeArea(.keyboard, edges: .bottom)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Start your note here…")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }
            }

            // Save status row
            HStack(spacing: 8) {
                if isSaving { ProgressView().scaleEffect(0.8) }
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
        // Autosave timer
        .onReceive(Timer.publish(every: autoSaveIntervalSeconds, on: .main, in: .common).autoconnect()) { _ in
            autoSaveIfNeeded()
        }
        .onDisappear {
            autoSaveIfNeeded()
        }
        .onAppear { editorController.showTokens = showTokens }
        .onChange(of: showTokens) { _, newValue in
            editorController.showTokens = newValue
            editorController.refreshPresentation()
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showTokens.toggle() }) {
                Text("Markdown")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(showTokens ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.trailing, 12)
            .padding(.bottom, 50)
        }
    }

    private var statusText: String {
        if isSaving { return "Saving…" }
        if lastSavedText == text, let when = lastSavedAt {
            let df = DateFormatter()
            df.timeStyle = .short
            df.dateStyle = .none
            return "Saved at \(df.string(from: when))"
        }
        return "Unsaved changes"
    }

    private func autoSaveIfNeeded() {
        guard text != lastSavedText else { return }
        isSaving = true
        onAutoSave(text)
        lastSavedText = text
        lastSavedAt = Date()
        isSaving = false
    }

    private func saveAndClose() {
        isSaving = true
        onSave(text)
        lastSavedText = text
        lastSavedAt = Date()
        isSaving = false
        if layoutStyle == .sheet {
            dismiss()
        }
    }

}
