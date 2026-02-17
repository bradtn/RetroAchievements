import WidgetKit
import SwiftUI

@main
struct RetroTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        GameTrackerWidget()
        AotwWidget()
        RecentAchievementsWidget()
        FriendActivityWidget()
    }
}
