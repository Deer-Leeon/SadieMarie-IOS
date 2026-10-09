import Foundation

/// Joins overlapping `load()` calls so tab prefetch and a tab's own
/// `.task` share one in-flight request instead of stacking spinners.
@MainActor
final class InFlightLoad {
    private var task: Task<Void, Never>?

    /// Join an in-flight pass. When `againIf` is true after that pass, run
    /// once more so a foreground refresh is not dropped behind a poll.
    func run(
        againIf: @escaping @MainActor () -> Bool = { false },
        _ work: @escaping @MainActor () async -> Void
    ) async {
        if let task {
            await task.value
            return
        }
        let created = Task { @MainActor in
            repeat {
                await work()
            } while againIf() && !Task.isCancelled
        }
        task = created
        await created.value
        if task == created {
            task = nil
        }
    }
}
