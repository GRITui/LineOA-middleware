import Fluent
import PostgresNIO

extension DatabaseError {
    /// True if the underlying error is a PostgreSQL unique-constraint violation
    /// (SQLSTATE 23505, e.g. duplicate `(customer_id, session_id)` on bookings).
    var isUniqueConstraintViolation: Bool {
        guard let pgError = self as? PostgresError else { return false }
        return pgError.code == .uniqueViolation
    }
}