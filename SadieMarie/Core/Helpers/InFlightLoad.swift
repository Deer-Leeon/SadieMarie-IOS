import Foundation

/// Joins overlapping `load()` calls so tab prefetch and a tab's own
/// `.task` share one in-flight request instead of stacking spinners.
@MainActor
final class InFlightLoad {
    private var task: Task<Void, Never>?

    func run(_ work: @escaping @MainActor () async -> Void) async {
        if let task {
            await task.value
            return
        }
        let created = Task { @MainActor in
            await work()
        }
        task = created
        await created.value
        if task == created {
            task = nil
        }
    }
}
