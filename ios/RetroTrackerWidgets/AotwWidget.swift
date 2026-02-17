import WidgetKit
import SwiftUI

struct AotwEntry: TimelineEntry {
    let date: Date
    let data: AotwData
    let achievementImage: UIImage?
}

struct AotwProvider: TimelineProvider {
    func placeholder(in context: Context) -> AotwEntry {
        AotwEntry(date: Date(), data: .placeholder, achievementImage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (AotwEntry) -> Void) {
        let data = SharedDataManager.shared.getAotwData()
        let image = ImageLoader.shared.loadImage(from: data.achievementIcon)
        completion(AotwEntry(date: Date(), data: data, achievementImage: image))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AotwEntry>) -> Void) {
        let data = SharedDataManager.shared.getAotwData()
        let image = ImageLoader.shared.loadImage(from: data.achievementIcon)
        let entry = AotwEntry(date: Date(), data: data, achievementImage: image)

        // Refresh daily
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct AotwWidget: Widget {
    let kind: String = "AotwWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AotwProvider()) { entry in
            AotwWidgetView(entry: entry)
        }
        .configurationDisplayName("Achievement of the Week")
        .description("See the current Achievement of the Week")
        .supportedFamilies([.systemMedium])
    }
}

struct AotwWidgetView: View {
    var entry: AotwEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(red: 0.07, green: 0.07, blue: 0.07))

            if entry.data.hasData {
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
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // AOTW Label
                        Text("ACHIEVEMENT OF THE WEEK")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                            .tracking(1)

                        // Achievement Title
                        Text(entry.data.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)

                        // Game Info
                        Text(entry.data.game)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)

                        HStack {
                            Text(entry.data.consoleName)
                                .font(.caption)
                                .foregroundColor(.gray)

                            Spacer()

                            // Points
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                Text("\(entry.data.points)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                            }
                        }
                    }
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)

                    Text("Achievement of the Week")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Open the app to load data")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
        }
    }
}

struct AotwWidget_Previews: PreviewProvider {
    static var previews: some View {
        AotwWidgetView(entry: AotwEntry(date: Date(), data: .placeholder, achievementImage: nil))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
