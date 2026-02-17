import WidgetKit
import SwiftUI

struct RecentAchievementsEntry: TimelineEntry {
    let date: Date
    let achievement: RecentAchievementData?
    let achievementImage: UIImage?
    let index: Int
    let total: Int
}

struct RecentAchievementsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentAchievementsEntry {
        RecentAchievementsEntry(
            date: Date(),
            achievement: .placeholder,
            achievementImage: nil,
            index: 0,
            total: 1
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentAchievementsEntry) -> Void) {
        let achievements = SharedDataManager.shared.getRecentAchievements()
        let achievement = achievements.first
        let image = achievement.flatMap { ImageLoader.shared.loadImage(from: $0.achievementIcon) }
        completion(RecentAchievementsEntry(
            date: Date(),
            achievement: achievement,
            achievementImage: image,
            index: 0,
            total: achievements.count
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentAchievementsEntry>) -> Void) {
        let achievements = SharedDataManager.shared.getRecentAchievements()

        guard !achievements.isEmpty else {
            let entry = RecentAchievementsEntry(
                date: Date(),
                achievement: nil,
                achievementImage: nil,
                index: 0,
                total: 0
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }

        // Create timeline entries cycling through achievements every 30 seconds
        var entries: [RecentAchievementsEntry] = []
        let now = Date()

        for (index, achievement) in achievements.enumerated() {
            let entryDate = Calendar.current.date(byAdding: .second, value: index * 30, to: now)!
            let image = ImageLoader.shared.loadImage(from: achievement.achievementIcon)
            entries.append(RecentAchievementsEntry(
                date: entryDate,
                achievement: achievement,
                achievementImage: image,
                index: index,
                total: achievements.count
            ))
        }

        // Refresh timeline after all entries have cycled
        let totalDuration = achievements.count * 30
        let nextUpdate = Calendar.current.date(byAdding: .second, value: totalDuration, to: now)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct RecentAchievementsWidget: Widget {
    let kind: String = "RecentAchievementsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentAchievementsProvider()) { entry in
            RecentAchievementsWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent Achievements")
        .description("See your recently earned achievements")
        .supportedFamilies([.systemMedium])
    }
}

struct RecentAchievementsWidgetView: View {
    var entry: RecentAchievementsEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(red: 0.07, green: 0.07, blue: 0.07))

            if let achievement = entry.achievement {
                HStack(spacing: 12) {
                    // Achievement Badge
                    if let image = entry.achievementImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(.yellow)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // Header with indicator
                        HStack {
                            Text("RECENT ACHIEVEMENT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                .tracking(1)

                            Spacer()

                            if entry.total > 1 {
                                Text("\(entry.index + 1)/\(entry.total)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }

                        // Achievement Title
                        Text(achievement.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        // Game Info
                        Text(achievement.gameTitle)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)

                        HStack {
                            // Console
                            Text(achievement.consoleName)
                                .font(.caption)
                                .foregroundColor(.gray)

                            Spacer()

                            // Points with hardcore indicator
                            HStack(spacing: 4) {
                                if achievement.hardcore {
                                    Text("HC")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color(red: 1.0, green: 0.84, blue: 0.0))
                                        .cornerRadius(4)
                                }

                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                Text("\(achievement.points)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                            }
                        }

                        // Timestamp
                        Text(achievement.timestamp)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)

                    Text("No Recent Achievements")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Earn achievements to see them here")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
        }
    }
}

struct RecentAchievementsWidget_Previews: PreviewProvider {
    static var previews: some View {
        RecentAchievementsWidgetView(entry: RecentAchievementsEntry(
            date: Date(),
            achievement: .placeholder,
            achievementImage: nil,
            index: 0,
            total: 5
        ))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
