import Foundation

actor GitCommandScheduler {
    static let shared = GitCommandScheduler()

    private let maximumRunningCommands = 3
    private let maximumRunningByPriority: [GitCommandPriority: Int] = [
        .userInteractive: 2,
        .visible: 2,
        .background: 1
    ]

    private var runningTotal = 0
    private var runningByPriority: [GitCommandPriority: Int] = [:]
    private var waiters: [QueuedCommand] = []

    func acquire(priority: GitCommandPriority) async throws -> GitCommandPermit {
        let requestedAt = ProcessInfo.processInfo.systemUptime
        if canStart(priority: priority) {
            start(priority: priority)
            return GitCommandPermit(priority: priority, queueWaitMilliseconds: queueWaitMilliseconds(since: requestedAt))
        }

        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(QueuedCommand(id: id, priority: priority, requestedAt: requestedAt, continuation: continuation))
                resumeEligibleWaiters()
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }
    }

    func release(priority: GitCommandPriority) {
        runningTotal = max(0, runningTotal - 1)
        runningByPriority[priority] = max(0, (runningByPriority[priority] ?? 0) - 1)
        resumeEligibleWaiters()
    }

    private func resumeEligibleWaiters() {
        var didResume = true
        while didResume {
            didResume = false
            guard let index = nextEligibleWaiterIndex() else { return }
            let waiter = waiters.remove(at: index)
            start(priority: waiter.priority)
            waiter.continuation.resume(returning: GitCommandPermit(
                priority: waiter.priority,
                queueWaitMilliseconds: queueWaitMilliseconds(since: waiter.requestedAt)
            ))
            didResume = true
        }
    }

    private func cancelWaiter(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func nextEligibleWaiterIndex() -> Int? {
        for priority in [GitCommandPriority.userInteractive, .visible, .background] {
            if let index = waiters.firstIndex(where: { $0.priority == priority && canStart(priority: priority) }) {
                return index
            }
        }
        return nil
    }

    private func canStart(priority: GitCommandPriority) -> Bool {
        guard runningTotal < maximumRunningCommands else { return false }
        let runningForPriority = runningByPriority[priority] ?? 0
        let limit = maximumRunningByPriority[priority] ?? maximumRunningCommands
        return runningForPriority < limit
    }

    private func start(priority: GitCommandPriority) {
        runningTotal += 1
        runningByPriority[priority, default: 0] += 1
    }

    private func queueWaitMilliseconds(since startedAt: TimeInterval) -> Double {
        max(0, (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
    }

    private struct QueuedCommand {
        let id: UUID
        let priority: GitCommandPriority
        let requestedAt: TimeInterval
        let continuation: CheckedContinuation<GitCommandPermit, Error>
    }
}

struct GitCommandPermit: Sendable {
    let priority: GitCommandPriority
    let queueWaitMilliseconds: Double
}
