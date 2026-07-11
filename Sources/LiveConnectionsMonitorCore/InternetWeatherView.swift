import Charts
import SwiftUI

public struct InternetWeatherView: View {
    @StateObject private var model = InternetWeatherViewModel()
    public init() {}
    public var body: some View { ZStack { AppBackground(); ScrollView { VStack(alignment: .leading, spacing: 14) {
        HStack { VStack(alignment: .leading) { Text("Internet Weather").font(.title2.weight(.semibold)); Text("Local connection-quality measurements and ISP evidence history.").foregroundStyle(.secondary) }; Spacer(); Button { Task { await model.refresh() } } label: { Label("Measure Now", systemImage: "gauge.with.dots.needle.50percent") }.disabled(model.measuring) }
        if let latest = model.latest { LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))]) { metric("Latency", latest.latencyMS.map { "\($0.formatted(.number.precision(.fractionLength(1)))) ms" } ?? "Unavailable", "timer", .green); metric("Packet loss", latest.packetLossPercent.map { "\($0.formatted())%" } ?? "Unavailable", "waveform.path", latest.packetLossPercent ?? 0 > 0 ? .orange : .green); metric("DNS response", latest.dnsResponseMS.map { "\($0.formatted()) ms" } ?? "Unavailable", "network", .cyan); metric("IPv4", latest.ipv4Available ? "Available" : "No route", "4.circle", latest.ipv4Available ? .green : .red); metric("IPv6", latest.ipv6Available ? "Available" : "No route", "6.circle", latest.ipv6Available ? .green : .secondary); metric("Gateway", latest.gateway ?? "Unavailable", "router", .blue) }
        } else { ContentUnavailableView("No measurements yet", systemImage: "cloud.sun", description: Text("Measure now to create the first local quality sample.")) }
        GlassCard { VStack(alignment: .leading) { Text("Quality History").font(.headline); Chart(model.samples.suffix(500)) { sample in if let value = sample.latencyMS { LineMark(x: .value("Time", sample.timestamp), y: .value("Latency", value)).foregroundStyle(.green) }; if let value = sample.dnsResponseMS { LineMark(x: .value("Time", sample.timestamp), y: .value("DNS", value)).foregroundStyle(.cyan) } }.frame(height: 240); Text("Green: latency · Cyan: DNS response. Samples are stored locally. Disable all logs prevents new history writes.").font(.caption).foregroundStyle(.secondary) } }
        Text("Probes Cloudflare's 1.1.1.1 with three ICMP echoes and resolves example.com with the configured DNS path. A failed probe may reflect filtering, not a complete outage. No public-IP or ISP lookup is sent to a third-party API.").font(.caption).foregroundStyle(.secondary)
    }.padding(16) } }.task { await model.load(); if model.samples.isEmpty { await model.refresh() } } }
    private func metric(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View { GlassMetricCard(title, value: value, systemImage: icon, accent: color) }
}
