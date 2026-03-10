import Foundation

enum RateLimitError: Error, CustomStringConvertible {
    case createRateLimitExceeded
    case deleteRateLimitExceeded
    case lifetimeDeleteCapReached(count: Int)

    var description: String {
        switch self {
        case .createRateLimitExceeded:
            return "Rate limit exceeded: too many create operations. Please wait before creating more reminders."
        case .deleteRateLimitExceeded:
            return "Rate limit exceeded: too many delete operations. Please wait before deleting more items."
        case .lifetimeDeleteCapReached(let count):
            return "Safety limit reached: \(count) items have been deleted this session. Restart the server to reset."
        }
    }
}

actor RateLimiter {
    private let createLimit: Int
    private let deleteLimit: Int
    private let windowSeconds: TimeInterval
    private let lifetimeDeleteCap: Int

    private var createTimestamps: [Date] = []
    private var deleteTimestamps: [Date] = []
    private var lifetimeDeleteCount: Int = 0

    init(createLimit: Int = 50, deleteLimit: Int = 10, windowSeconds: TimeInterval = 60, lifetimeDeleteCap: Int = 100) {
        self.createLimit = createLimit
        self.deleteLimit = deleteLimit
        self.windowSeconds = windowSeconds
        self.lifetimeDeleteCap = lifetimeDeleteCap
    }

    func checkCreate() throws {
        prune(&createTimestamps)
        guard createTimestamps.count < createLimit else {
            throw RateLimitError.createRateLimitExceeded
        }
    }

    func recordCreate() {
        createTimestamps.append(Date())
    }

    func checkDelete() throws {
        guard lifetimeDeleteCount < lifetimeDeleteCap else {
            throw RateLimitError.lifetimeDeleteCapReached(count: lifetimeDeleteCount)
        }
        prune(&deleteTimestamps)
        guard deleteTimestamps.count < deleteLimit else {
            throw RateLimitError.deleteRateLimitExceeded
        }
    }

    func recordDelete() {
        deleteTimestamps.append(Date())
        lifetimeDeleteCount += 1
    }

    private func prune(_ timestamps: inout [Date]) {
        let cutoff = Date().addingTimeInterval(-windowSeconds)
        timestamps.removeAll { $0 < cutoff }
    }
}
