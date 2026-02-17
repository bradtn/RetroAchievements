import WidgetKit
import SwiftUI

struct GameTrackerEntry: TimelineEntry {
    let date: Date
    let data: GameTrackerData
    let gameImage: UIImage?
}

struct GameTrackerProvider: TimelineProvider {
    func placeholder(in context: Context) -> GameTrackerEntry {
        GameTrackerEntry(date: Date(), data: .placeholder, gameImage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (GameTrackerEntry) -> Void) {
        let data = SharedDataManager.shared.getGameTrackerData()
        let image = ImageLoader.shared.loadImage(from: data.imageUrl)
        completion(GameTrackerEntry(date: Date(), data: data, gameImage: image))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GameTrackerEntry>) -> Void) {
        let data = SharedDataManager.shared.getGameTrackerData()
        let image = ImageLoader.shared.loadImage(from: data.imageUrl)
        let entry = GameTrackerEntry(date: Date(), data: data, gameImage: image)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct GameTrackerWidget: Widget {
    let kind: String = "GameTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GameTrackerProvider()) { entry in
            GameTrackerWidgetView(entry: entry)
        }
        .configurationDisplayName("Game Tracker")
        .description("Track your progress on a pinned game")
        .supportedFamilies([.systemMedium])
    }
}

struct GameTrackerWidgetView: View {
    var entry: GameTrackerEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(red: 0.07, green: 0.07, blue: 0.07))

            if entry.data.hasData {
                HStack(spacing: 12) {
                    // Game Image
                    if let image = entry.gameImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "gamecontroller.fill")
                                    .foregroundColor(.gray)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // Game Title
                        Text(entry.data.gameTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)

                        // Console Name
                        Text(entry.data.consoleName)
                            .font(.caption)
                            .foregroundColor(.gray)

                        Spacer()

                        // Progress
                        HStack {
                            Text("\(entry.data.earned)/\(entry.data.total)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))

                            Spacer()

                            Text("\(Int(entry.data.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(red: 1.0, green: 0.84, blue: 0.0))
                                    .frame(width: geometry.size.width * CGFloat(entry.data.progress), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)

                    Text("No Game Tracked")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Pin a game in Favorites to track it here")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
}

struct GameTrackerWidget_Previews: PreviewProvider {
    static var previews: some View {
        GameTrackerWidgetView(entry: GameTrackerEntry(date: Date(), data: .placeholder, gameImage: nil))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
