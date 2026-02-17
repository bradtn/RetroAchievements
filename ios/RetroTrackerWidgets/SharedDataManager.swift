import Foundation

class SharedDataManager {
    static let shared = SharedDataManager()

    private let appGroupId = "group.com.spectersystems.retrotrack"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    private init() {}

    // MARK: - String Values
    func getString(_ key: String) -> String? {
        userDefaults?.string(forKey: key)
    }

    // MARK: - Int Values
    func getInt(_ key: String) -> Int {
        userDefaults?.integer(forKey: key) ?? 0
    }

    // MARK: - JSON Values
    func getJSON<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let jsonString = getString(key),
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - Game Tracker Widget Data
    func getGameTrackerData() -> GameTrackerData {
        GameTrackerData(
            gameTitle: getString("widget_game_title") ?? "No game tracked",
            consoleName: getString("widget_console_name") ?? "",
            earned: getInt("widget_earned"),
            total: getInt("widget_total"),
            gameId: getInt("widget_game_id"),
            imageUrl: getString("widget_image_url") ?? ""
        )
    }

    // MARK: - Recent Achievements Widget Data
    func getRecentAchievements() -> [RecentAchievementData] {
        getJSON("widget_recent_achievements", as: [RecentAchievementData].self) ?? []
    }

    // MARK: - Streak Widget Data
    func getStreakData() -> StreakData {
        StreakData(
            currentStreak: getInt("widget_current_streak"),
            bestStreak: getInt("widget_best_streak")
        )
    }

    // MARK: - AOTW Widget Data
    func getAotwData() -> AotwData {
        AotwData(
            title: getString("widget_aotw_title") ?? "Achievement of the Week",
            game: getString("widget_aotw_game") ?? "",
            consoleName: getString("widget_aotw_console") ?? "",
            points: getInt("widget_aotw_points"),
            gameId: getInt("widget_aotw_game_id"),
            achievementIcon: getString("widget_aotw_achievement_icon") ?? "",
            gameIcon: getString("widget_aotw_game_icon") ?? ""
        )
    }

    // MARK: - Friend Activity Widget Data
    func getFriendActivity() -> [FriendActivityData] {
        getJSON("widget_friend_activity", as: [FriendActivityData].self) ?? []
    }
}
