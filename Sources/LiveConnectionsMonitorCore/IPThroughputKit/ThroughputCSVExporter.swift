import Foundation

public enum ThroughputCSVExporter {
    public static func csv(samples: [ThroughputSample]) -> String {
        let header = "timestamp,ipAddress,bytesIn,bytesOut,bytesTotal,bitsPerSecondIn,bitsPerSecondOut,bitsPerSecondTotal"
        let rows = samples.map { sample in
            [
                ISO8601DateFormatter().string(from: sample.timestamp),
                sample.ipAddress,
                String(sample.bytesIn),
                String(sample.bytesOut),
                String(sample.bytesTotal),
                String(sample.bitsPerSecondIn),
                String(sample.bitsPerSecondOut),
                String(sample.bitsPerSecondTotal)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
}
