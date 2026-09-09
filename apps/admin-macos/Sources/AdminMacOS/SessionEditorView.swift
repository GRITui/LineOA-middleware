import SwiftUI

// Create/edit form for a Session. Backing fields match SessionController.SessionInput
// on the backend: title, date, startTime, endTime, capacity, status.
// See GitHub issue #28.
struct SessionEditorView: View {
    let session: Session?
    let onSaved: (Session) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var date: Date
    @State private var startTime: String
    @State private var endTime: String
    @State private var capacity: Int
    @State private var status: SessionStatus
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(session: Session?, onSaved: @escaping (Session) -> Void, onCancel: @escaping () -> Void) {
        self.session = session
        self.onSaved = onSaved
        self.onCancel = onCancel
        _title = State(initialValue: session?.title ?? "")
        _date = State(initialValue: session?.date ?? Date())
        _startTime = State(initialValue: session?.startTime ?? "09:00")
        _endTime = State(initialValue: session?.endTime ?? "10:00")
        _capacity = State(initialValue: session?.capacity ?? 10)
        _status = State(initialValue: session?.status ?? .open)
    }

    private var isEditing: Bool { session != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Edit Session" : "New Session")
                .font(.title2).bold()

            Form {
                TextField("Title", text: $title)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Start time (e.g. 09:00)", text: $startTime)
                TextField("End time (e.g. 10:00)", text: $endTime)
                Stepper("Capacity: \(capacity)", value: $capacity, in: 1...500)
                Picker("Status", selection: $status) {
                    ForEach(SessionStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.callout)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(isSaving ? "Saving…" : "Save") {
                    Task { await save() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving || title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 420)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let input = SessionInput(
            title: title,
            date: date,
            startTime: startTime,
            endTime: endTime,
            capacity: capacity,
            status: status
        )

        do {
            let saved: Session
            if let existingID = session?.id {
                saved = try await APIClient.shared.updateSession(id: existingID, input)
            } else {
                saved = try await APIClient.shared.createSession(input)
            }
            onSaved(saved)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
