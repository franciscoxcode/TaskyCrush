import SwiftUI

struct ReminderListEditor: View {
    @Binding var reminders: [TaskReminder]
    var dueTimeIsSet: Bool
    var maxCount: Int = 3
    var onFirstReminderAdded: () -> Void = {}
    @State private var selectedKind: TaskReminder.Kind = .relative

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if availableKinds.count > 1 {
                Picker("Reminder type", selection: $selectedKind) {
                    ForEach(availableKinds) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            reminderList

            if reminders.count < maxCount {
                Button(action: { addReminder(of: selectedKind) }) {
                    Label(addButtonLabel, systemImage: "plus.circle")
                }
                .disabled(!canAddReminder(of: selectedKind))
            }

        }
        .animation(.default, value: reminders)
        .onAppear {
            normalizeSelection()
            normalizeRemindersForCurrentDueTime()
        }
        .onChange(of: dueTimeIsSet) { _, _ in
            normalizeSelection()
            normalizeRemindersForCurrentDueTime()
        }
    }

    private var availableKinds: [TaskReminder.Kind] {
        dueTimeIsSet ? TaskReminder.Kind.allCases : [.absolute]
    }

    private var addButtonLabel: String {
        selectedKind == .relative ? "Add before due date" : "Add specific date"
    }

    private var matchingPairs: [(index: Int, reminder: TaskReminder)] {
        reminders.enumerated()
            .filter { $0.element.kind == selectedKind }
            .map { (index: $0.offset, reminder: $0.element) }
    }

    @ViewBuilder
    private var reminderList: some View {
        let pairs = matchingPairs
        if pairs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(reminders.isEmpty ? "No reminders yet" : "No reminders of this type")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(pairs, id: \.reminder.id) { pair in
                ReminderRowView(reminder: $reminders[pair.index]) {
                    removeReminder(pair.reminder.id)
                }
                .padding(.vertical, 4)
                if pair.reminder.id != pairs.last?.reminder.id {
                    Divider()
                }
            }
        }
    }

    private func addReminder(of kind: TaskReminder.Kind) {
        guard canAddReminder(of: kind) else { return }
        if reminders.isEmpty { onFirstReminderAdded() }
        var newReminder = TaskReminder(kind: kind)
        if !dueTimeIsSet && (newReminder.relativeUnit == .minutes || newReminder.relativeUnit == .hours) {
            newReminder.relativeUnit = .days
        }
        reminders.append(newReminder)
    }

    private func canAddReminder(of kind: TaskReminder.Kind) -> Bool {
        availableKinds.contains(kind) && reminders.count < maxCount
    }

    private func removeReminder(_ id: UUID) {
        reminders.removeAll { $0.id == id }
    }

    private func normalizeSelection() {
        if !availableKinds.contains(selectedKind) {
            selectedKind = availableKinds.first ?? .absolute
        }
    }

    private func normalizeRemindersForCurrentDueTime() {
        guard !dueTimeIsSet else { return }
        for index in reminders.indices {
            if reminders[index].kind == .relative {
                reminders[index].kind = .absolute
            }
        }
    }
}

private struct ReminderRowView: View {
    @Binding var reminder: TaskReminder
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                contentForSelectedKind
                Spacer(minLength: 0)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var contentForSelectedKind: some View {
        switch reminder.kind {
        case .relative:
            relativeControls
        case .absolute:
            DatePicker("When", selection: $reminder.absoluteDate, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
        }
    }

    private var relativeControls: some View {
        HStack(spacing: 12) {
            Button(action: decrementRelativeValue) {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
            .disabled(reminder.relativeValue <= 1)

            Text("\(reminder.relativeValue)")
                .font(.body.monospacedDigit())
                .frame(minWidth: 28)

            Button(action: incrementRelativeValue) {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.plain)

            Menu {
                Picker("Reminder unit", selection: $reminder.relativeUnit) {
                    ForEach(TaskReminder.RelativeUnit.allCases) { unit in
                        Text(unit.pluralName.capitalized).tag(unit)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(unitLabel)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            Text("before event")
                .foregroundStyle(.secondary)
        }
    }

    private var unitLabel: String {
        reminder.relativeValue == 1 ? reminder.relativeUnit.singularName : reminder.relativeUnit.pluralName
    }

    private func decrementRelativeValue() {
        reminder.relativeValue = max(1, reminder.relativeValue - 1)
    }

    private func incrementRelativeValue() {
        reminder.relativeValue = min(999, reminder.relativeValue + 1)
    }
}
