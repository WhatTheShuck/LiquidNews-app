import Foundation

extension Error {
    /// True for errors produced by cooperative task cancellation — either a
    /// Swift `CancellationError` or a `URLSession` request cancelled mid-flight
    /// (`URLError.cancelled`). These aren't real failures, so callers should
    /// swallow them rather than surfacing an error banner to the user.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
