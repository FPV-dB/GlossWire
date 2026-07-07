import AppKit
import SwiftUI

@MainActor
public final class IPSafetyViewModel: ObservableObject {
    @Published public var report: IPSafetyReport?
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private let service = IPSafetyService()
    private var settingsProvider: @MainActor () -> IPSafetyProviderSettings

    public init(settingsProvider: @escaping @MainActor () -> IPSafetyProviderSettings) {
        self.settingsProvider = settingsProvider
    }

    public func check(ip: String, refresh: Bool = false) {
        isLoading = true
        Task {
            let next = await service.check(ip: ip, settings: settingsProvider(), refresh: refresh)
            report = next
            isLoading = false
        }
    }

    public func copyReport() {
        guard let report else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.text(for: report), forType: .string)
    }

    public static func text(for report: IPSafetyReport) -> String {
        """
        IP Safety Report: \(report.ip)
        Risk: \(report.riskScore)/100 \(report.riskLabel.rawValue)
        Summary: \(report.summary)
        Reverse DNS: \(report.reverseDNS ?? "-")
        ASN/ISP: \(report.asn ?? "-")
        RDAP: \(report.rdapOrganisation ?? "-")
        Tor exit node: \(report.torExitNode.map { $0 ? "Yes" : "No" } ?? "-")
        DNSBL listings: \(report.dnsblListings.filter(\.listed).map(\.provider).joined(separator: ", "))
        Checked: \(report.lastChecked)
        """
    }
}

public struct IPSafetyReportView: View {
    @ObservedObject var viewModel: IPSafetyViewModel
    let ip: String

    public init(ip: String, viewModel: IPSafetyViewModel) {
        self.ip = ip
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("IP Safety Report", systemImage: "shield.lefthalf.filled")
                    .font(.title2.weight(.semibold))
                Spacer()
                if viewModel.isLoading { ProgressView().controlSize(.small) }
                Button("Refresh") { viewModel.check(ip: ip, refresh: true) }
                Button("Copy Report") { viewModel.copyReport() }.disabled(viewModel.report == nil)
            }

            if let report = viewModel.report {
                summary(report)
                providerDetails(report)
            } else {
                ContentUnavailableView("No report yet", systemImage: "shield")
            }
        }
        .padding(18)
        .frame(minWidth: 720, minHeight: 620)
        .task { if viewModel.report == nil { viewModel.check(ip: ip) } }
    }

    private func summary(_ report: IPSafetyReport) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(report.ip).font(.system(.title3, design: .monospaced).weight(.semibold))
                    Spacer()
                    Text("\(report.riskScore)/100 \(report.riskLabel.rawValue)")
                        .font(.headline)
                        .foregroundStyle(color(for: report.riskLabel))
                }
                Text(report.summary)
                Text(report.fromCache ? "Result came from cache." : "Fresh result.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    row("Reverse DNS", report.reverseDNS)
                    row("ASN / ISP", report.asn)
                    row("RDAP organisation", report.rdapOrganisation)
                    row("Country / region", report.countryRegion)
                    row("Tor exit node", report.torExitNode.map { $0 ? "Yes" : "No" })
                    row("Datacentre hint", report.datacentreHint)
                    row("Last checked", DateFormatter.localizedString(from: report.lastChecked, dateStyle: .short, timeStyle: .medium))
                }
            }
        }
    }

    private func providerDetails(_ report: IPSafetyReport) -> some View {
        List {
            Section("DNSBL Listings") {
                if report.dnsblListings.isEmpty {
                    Text("No DNSBL checks were run.")
                } else {
                    ForEach(report.dnsblListings) { item in
                        HStack {
                            Text(item.provider)
                            Spacer()
                            Text(item.listed ? "Listed" : "Not listed")
                                .foregroundStyle(item.listed ? .orange : .secondary)
                        }
                        if let error = item.error {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
            }
            Section("Provider Results") {
                ForEach(report.providerResults) { result in
                    DisclosureGroup("\(result.provider): \(result.status)") {
                        Text(result.detail.isEmpty ? "-" : result.detail)
                        if let error = result.error {
                            Text(error).foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    private func row(_ key: String, _ value: String?) -> some View {
        GridRow {
            Text(key).foregroundStyle(.secondary)
            Text(value?.isEmpty == false ? value! : "-")
        }
    }

    private func color(for label: IPSafetyRiskLabel) -> Color {
        switch label {
        case .low: .green
        case .medium: .orange
        case .high: .red
        case .critical: .purple
        case .unknown: .secondary
        }
    }
}
