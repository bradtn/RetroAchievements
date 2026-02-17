import WidgetKit
import SwiftUI

struct FriendActivityEntry: TimelineEntry {
    let date: Date
    let activity: FriendActivityData?
    let avatarImage: UIImage?
    let index: Int
    let total: Int
}

struct FriendActivityProvider: TimelineProvider {
    func placeholder(in context: Context) -> FriendActivityEntry {
        FriendActivityEntry(
            date: Date(),
            activity: .placeholder,
            avatarImage: nil,
            index: 0,
            total: 1
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FriendActivityEntry) -> Void) {
        let activities = SharedDataManager.shared.getFriendActivity()
        let activity = activities.first
        let image = activity.flatMap { ImageLoader.shared.loadImage(from: $0.userAvatar) }
        completion(FriendActivityEntry(
            date: Date(),
            activity: activity,
            avatarImage: image,
            index: 0,
            total: activities.count
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FriendActivityEntry>) -> Void) {
        let activities = SharedDataManager.shared.getFriendActivity()

        guard !activities.isEmpty else {
            let entry = FriendActivityEntry(
                date: Date(),
                activity: nil,
                avatarImage: nil,
                index: 0,
                total: 0
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }

        // Create timeline entries cycling through activities every 2 minutes
        var entries: [FriendActivityEntry] = []
        let now = Date()

        for (index, activity) in activities.enumerated() {
            let entryDate = Calendar.current.date(byAdding: .minute, value: index * 2, to: now)!
            let image = ImageLoader.shared.loadImage(from: activity.userAvatar)
            entries.append(FriendActivityEntry(
                date: entryDate,
                activity: activity,
                avatarImage: image,
                index: index,
                total: activities.count
            ))
        }

        // Refresh timeline after all entries have cycled
        let totalMinutes = activities.count * 2
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: totalMinutes, to: now)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct FriendActivityWidget: Widget {
    let kind: String = "FriendActivityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FriendActivityProvider()) { entry in
            FriendActivityWidgetView(entry: entry)
        }
        .configurationDisplayName("Friend Activity")
        .description("See what your friends are achieving")
        .supportedFamilies([.systemMedium])
    }
}

struct FriendActivityWidgetView: View {
    var entry: FriendActivityEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(red: 0.07, green: 0.07, blue: 0.07))

            if let activity = entry.activity {
                HStack(spacing: 12) {
                    // User Avatar
                    if let image = entry.avatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // Header with indicator
                        HStack {
                            Text("FRIEND ACTIVITY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 0.4, green: 0.6, blue: 1.0))
                                .tracking(1)

                            Spacer()

                            if entry.total > 1 {
                                Text("\(entry.index + 1)/\(entry.total)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }

                        // Username
                        Text(activity.username)
                            .font(.headline)
                            .foregroundColor(.white)

                        // Achievement earned
                        Text("earned \(activity.achievementTitle)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)

                        HStack {
                            // Game
                            Text(activity.gameTitle)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)

                            Spacer()

                            // Timestamp
                            Text(activity.timestamp)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)

                    Text("No Friend Activity")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Follow users to see their activity")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
        }
    }
}

struct FriendActivityWidget_Previews: PreviewProvider {
    static var previews: some View {
        FriendActivityWidgetView(entry: FriendActivityEntry(
            date: Date(),
            activity: .placeholder,
            avatarImage: nil,
            index: 0,
            total: 3
        ))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
