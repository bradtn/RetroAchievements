import Foundation

// MARK: - Game Tracker Data
struct GameTrackerData {
    let gameTitle: String
    let consoleName: String
    let earned: Int
    let total: Int
    let gameId: Int
    let imageUrl: String

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(earned) / Double(total)
    }

    var hasData: Bool {
        gameId > 0
    }

    static let placeholder = GameTrackerData(
        gameTitle: "Super Mario Bros.",
        consoleName: "NES",
        earned: 15,
        total: 25,
        gameId: 1,
        imageUrl: ""
    )
}

// MARK: - Recent Achievement Data
struct RecentAchievementData: Codable {
    let title: String
    let gameTitle: String
    let consoleName: String
    let points: Int
    let hardcore: Bool
    let timestamp: String
    let achievementIcon: String
    let gameIcon: String

    static let placeholder = RecentAchievementData(
        title: "First Steps",
        gameTitle: "Super Mario Bros.",
        consoleName: "NES",
        points: 10,
        hardcore: true,
        timestamp: "2h ago",
        achievementIcon: "",
        gameIcon: ""
    )
}

// MARK: - Streak Data
struct StreakData {
    let currentStreak: Int
    let bestStreak: Int

    var hasData: Bool {
        currentStreak > 0 || bestStreak > 0
    }

    static let placeholder = StreakData(
        currentStreak: 7,
        bestStreak: 30
    )
}

// MARK: - Achievement of the Week Data
struct AotwData {
    let title: String
    let game: String
    let consoleName: String
    let points: Int
    let gameId: Int
    let achievementIcon: String
    let gameIcon: String

    var hasData: Bool {
        !title.isEmpty && !game.isEmpty
    }

    static let placeholder = AotwData(
        title: "Master Collector",
        game: "Legend of Zelda",
        consoleName: "NES",
        points: 25,
        gameId: 1,
        achievementIcon: "",
        gameIcon: ""
    )
}

// MARK: - Friend Activity Data
struct FriendActivityData: Codable {
    let username: String
    let userAvatar: String
    let achievementTitle: String
    let gameTitle: String
    let timestamp: String
    let achievementIcon: String
    let gameIcon: String

    static let placeholder = FriendActivityData(
        username: "Player1",
        userAvatar: "",
        achievementTitle: "Victory!",
        gameTitle: "Sonic the Hedgehog",
        timestamp: "5m",
        achievementIcon: "",
        gameIcon: ""
    )
}
