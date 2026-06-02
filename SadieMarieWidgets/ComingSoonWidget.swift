import SwiftUI
import WidgetKit

struct ComingSoonWidgetEntry: TimelineEntry {
    let date: Date
}

struct ComingSoonWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComingSoonWidgetEntry {
        ComingSoonWidgetEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComingSoonWidgetEntry) -> Void) {
        completion(ComingSoonWidgetEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComingSoonWidgetEntry>) -> Void) {
        let entry = ComingSoonWidgetEntry(date: .now)
        let next = Calendar.current.date(byAdding: .hour, value: 12, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct ComingSoonWidgetView: View {
    var entry: ComingSoonWidgetProvider.Entry

    var body: some View {
        VStack(spacing: 8) {
            Text("Sadie Marie")
                .font(.headline)
            Text("Coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct ComingSoonWidget: Widget {
    let kind: String = "ComingSoonWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComingSoonWidgetProvider()) { entry in
            ComingSoonWidgetView(entry: entry)
        }
        .configurationDisplayName("Sadie Marie")
        .description("Studio widgets are on the way.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
