import Foundation

/// The tree grows on every ounce you've ever logged, so it's a record of the
/// whole habit rather than just today.
enum TreeGrowth {
    static let stages: [(name: String, ounces: Double)] = [
        ("Seed", 0),
        ("Sprout", 64),
        ("Seedling", 250),
        ("Sapling", 750),
        ("Young tree", 1600),
        ("Full tree", 3000),
        ("Blossoming", 5000)
    ]

    static func stageIndex(for ounces: Double) -> Int {
        var index = 0
        for (i, stage) in stages.enumerated() where ounces >= stage.ounces { index = i }
        return index
    }

    static func stageName(for ounces: Double) -> String {
        stages[stageIndex(for: ounces)].name
    }

    static func nextStage(for ounces: Double) -> (name: String, ounces: Double)? {
        let index = stageIndex(for: ounces)
        guard index + 1 < stages.count else { return nil }
        return stages[index + 1]
    }

    /// How far along you are between this stage and the next (0–1).
    static func progressToNextStage(for ounces: Double) -> Double {
        let index = stageIndex(for: ounces)
        guard let next = nextStage(for: ounces) else { return 1 }
        let start = stages[index].ounces
        let span = next.ounces - start
        guard span > 0 else { return 1 }
        return min(max((ounces - start) / span, 0), 1)
    }

    static func ouncesToNextStage(for ounces: Double) -> Double? {
        guard let next = nextStage(for: ounces) else { return nil }
        return max(next.ounces - ounces, 0)
    }

    /// 0–1 used for drawing. Eased so early days show visible progress.
    static func growth(for ounces: Double) -> Double {
        let last = stages.last?.ounces ?? 5000
        return pow(min(max(ounces / last, 0), 1), 0.55)
    }
}
