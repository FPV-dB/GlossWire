import Foundation
import SwiftUI

public struct CountryCatalogEntry: Identifiable, Hashable, Sendable {
    public let code: String
    public let name: String
    public var id: String { code }

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

public struct CountryBlockCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selection = Set<String>()
    @State private var includeIPv4 = true
    @State private var includeIPv6 = true
    @State private var confirmingImport = false

    private let existingCodes: Set<String>
    private let onImport: ([CountryCatalogEntry], Bool, Bool) -> Void

    public init(existingCodes: Set<String>, onImport: @escaping ([CountryCatalogEntry], Bool, Bool) -> Void) {
        self.existingCodes = existingCodes
        self.onImport = onImport
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            selectionToolbar
            List(filteredCountries) { country in
                countryRow(country)
            }
            .listStyle(.inset)
            .searchable(text: $searchText, prompt: "Search countries or country codes")
            Divider()
            footer
        }
        .frame(minWidth: 620, idealWidth: 700, minHeight: 620, idealHeight: 700)
        .alert("Import selected country ranges?", isPresented: $confirmingImport) {
            Button("Cancel", role: .cancel) {}
            Button("Import \(selection.count) Countr\(selection.count == 1 ? "y" : "ies")", role: .destructive) {
                let selected = Self.countries.filter { selection.contains($0.code) }
                onImport(selected, includeIPv4, includeIPv6)
                dismiss()
            }
        } message: {
            Text("Country blocking is broad and can interrupt legitimate websites, cloud services, updates, games, VPNs and CDNs. Imported countries remain disabled until you enable them in Country Blocking.")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text("Choose countries")
                    .font(.title2.weight(.semibold))
                Text("Select one or more IP allocation lists supplied by IPdeny.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") { dismiss() }
        }
        .padding(18)
    }

    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            Button("Select visible") {
                selection.formUnion(filteredCountries.map(\.code))
            }
            Button("Clear selection") { selection.removeAll() }
                .disabled(selection.isEmpty)
            Spacer()
            Text("\(selection.count) selected")
                .font(.callout.weight(.semibold))
                .foregroundStyle(selection.isEmpty ? Color.secondary : Color.blue)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func countryRow(_ country: CountryCatalogEntry) -> some View {
        Toggle(isOn: Binding(
            get: { selection.contains(country.code) },
            set: { selected in
                if selected { selection.insert(country.code) } else { selection.remove(country.code) }
            }
        )) {
            HStack(spacing: 12) {
                Text(Self.flag(for: country.code))
                    .font(.title2)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(country.name)
                        .font(.body.weight(.medium))
                    Text(country.code)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if existingCodes.contains(country.code) {
                    Label("Imported", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .toggleStyle(.checkbox)
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Address families")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Toggle("IPv4", isOn: $includeIPv4)
                    Toggle("IPv6", isOn: $includeIPv6)
                }
                .toggleStyle(.checkbox)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("Lists are imported disabled")
                    .font(.caption.weight(.semibold))
                Text("Review and enable them on the Country Blocking page.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button {
                confirmingImport = true
            } label: {
                Label("Review Import", systemImage: "square.and.arrow.down.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selection.isEmpty || (!includeIPv4 && !includeIPv6))
        }
        .padding(18)
    }

    private var filteredCountries: [CountryCatalogEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Self.countries }
        return Self.countries.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.code.localizedCaseInsensitiveContains(query)
        }
    }

    private static let countries: [CountryCatalogEntry] = Locale.Region.isoRegions.compactMap { region in
        let code = region.identifier.uppercased()
        guard code.count == 2, let name = Locale.current.localizedString(forRegionCode: code) else { return nil }
        return CountryCatalogEntry(code: code, name: name)
    }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    private static func flag(for code: String) -> String {
        code.uppercased().unicodeScalars.compactMap { scalar in
            UnicodeScalar(127397 + scalar.value).map(String.init)
        }.joined()
    }
}
