import SwiftUI

// Session list + entry point for create/edit and per-session bookings.
// See GitHub issue #28.
struct SessionListView: View {
    @State private var sessions: [Session] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedSession: Session?
    @State private var showingEditor = false
    @State private var editingSession: Session?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        NavigationSplitView {
            List(sessions, selection: $selectedSession) { session in
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title).font(.headline)
                    Text("\(Self.dateFormatter.string(from: session.date))  \(session.startTime)-\(session.endTime)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(session.bookedCount ?? 0)/\(session.capacity) booked  ·  \((session.status ?? .open).displayName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .tag(session)
                .padding(.vertical, 2)
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem {
                    Button {
                        editingSession = nil
                        showingEditor = true
                    } label: {
                        Label("New Session", systemImage: "plus")
                    }
                }
                ToolbarItem {
                    Button {
                        Task { await load() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        } detail: {
            if let selectedSession {
                SessionDetailView(
                    session: selectedSession,
                    onEdit: {
                        editingSession = selectedSession
                        showingEditor = true
                    }
                )
                .id(selectedSession.id)
            } else {
                ContentUnavailableFallback()
            }
        }
        .sheet(isPresented: $showingEditor) {
            SessionEditorView(session: editingSession) { saved in
                showingEditor = false
                Task { await load(selecting: saved) }
            } onCancel: {
                showingEditor = false
            }
        }
        .task { await load() }
        .overlay {
            if isLoading && sessions.isEmpty {
                ProgressView("Loading sessions…")
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func load(selecting session: Session? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            sessions = try await APIClient.shared.listSessions()
            if let session, let match = sessions.first(where: { $0.id == session.id }) {
                selectedSession = match
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ContentUnavailableFallback: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Select a session")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
