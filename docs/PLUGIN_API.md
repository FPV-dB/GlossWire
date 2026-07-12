# GlossWire Plugin API v1

GlossWire discovers plugin directories under:

- `~/Library/Application Support/GlossWire/Plugins`
- `~/Library/Application Support/Live Connections Monitor/Plugins`

Each directory must contain `plugin.json`:

```json
{
  "identifier": "com.example.glosswire.catalog",
  "name": "Example Service Catalog",
  "version": "1.0.0",
  "apiVersion": 1,
  "capabilities": ["metadataCatalog", "serviceRecognition"],
  "executable": null,
  "minimumGlossWireVersion": "1.0"
}
```

Supported capability names are `metadataCatalog`, `reverseDNS`, `geoIP`, `reputation`, `tlsInspection`, `serviceRecognition`, `reportExporter`, and `networkDiscovery`.

Data-only plugins may declare only `metadataCatalog` and `serviceRecognition`. A capability that can perform work requires an executable inside the plugin directory, a valid macOS code signature, and a stable TeamIdentifier. Paths escaping the plugin directory are rejected. GlossWire does not load plugin executables into its main process; executable requests are reserved for the isolated `GlossWirePluginHostBoundary` transport.

Discovery and validation do not grant network, filesystem, scanning, firewall, or packet access. Runtime permission and payload schemas must be added per capability before executable dispatch is enabled.

## Network Extension bridge

The flow-provider bridge expects a signed extension with bundle identifier `com.fpvdB.GlossWire.FlowProvider`. GlossWire reports extension readiness separately from active capability. An embedded extension still requires the Apple Network Extension entitlement, user approval, provider activation, and a working flow transport before per-flow bytes or per-app enforcement can be reported.

The current production bundle deliberately falls back to the polling provider because it has no approved embedded flow extension. The bridge DTO and transport protocols provide the integration boundary without overstating telemetry.
