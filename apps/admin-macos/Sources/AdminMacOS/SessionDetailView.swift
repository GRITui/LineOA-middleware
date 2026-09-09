import SwiftUI

// Read-only detail for a session plus its bookings/customers list.
// See GitHub issue #28.
struct SessionDetailView: View {
    let session: Session
    let onEdit: () -> Void

    @State private var bookings: [BookingWithCustomer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.title).font(.title2).bold()
                    Spacer()
                    Button("Edit", action: onEdit)
                }
                Text(Self.dateFormatter.string(from: session.date))
                    .foregroundStyle(.secondary)
                Text("\(session.startTime) – \(session.endTime)")
                    .foregroundStyle(.secondary)
                Text("Capacity: \(session.bookedCount ?? 0)/\(session.capacity)  ·  Status: \((session.status ?? .open).displayName)")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Bookings").font(.headline)

            if isLoading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            } else if bookings.isEmpty {
                Text("No bookings yet.").foregroundStyle(.secondary)
            } else {
                Table(bookings) {
                    TableColumn("Customer") { Text($0.customerName) }
                    TableColumn("LINE User ID") { Text($0.customerLineUserID) }
                    TableColumn("Phone") { Text($0.customerPhone ?? "—") }
                    TableColumn("Email") { Text($0.customerEmail ?? "—") }
                    TableColumn("Status") { Text($0.status == .confirmed ? "Confirmed" : "Cancelled") }
                }
            }

            Spacer()
        }
        .padding()
        .task(id: session.id) { await load() }
    }

    private func load() async {
        guard let id = session.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            bookings = try await APIClient.shared.bookings(forSession: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
