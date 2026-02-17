import WidgetKit
import SwiftUI

struct StreakEntry: TimelineEntry {
    let date: Date
    let data: StreakData
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let data = SharedDataManager.shared.getStreakData()
        completion(StreakEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let data = SharedDataManager.shared.getStreakData()
        let entry = StreakEntry(date: Date(), data: data)

        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Track your achievement streak")
        .supportedFamilies([.systemSmall])
    }
}

struct StreakWidgetView: View {
    var entry: StreakEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(red: 0.07, green: 0.07, blue: 0.07))

            VStack(spacing: 8) {
                // Fire emoji for streak
                Text("🔥")
                    .font(.system(size: 40))

                // Current streak
                Text("\(entry.data.currentStreak)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Day Streak")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Best streak
                HStack(spacing: 4) {
                    Text("Best:")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("\(entry.data.bestStreak)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                }
            }
            .padding()
        }
    }
}

struct StreakWidget_Previews: PreviewProvider {
    static var previews: some View {
        StreakWidgetView(entry: StreakEntry(date: Date(), data: .placeholder))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
