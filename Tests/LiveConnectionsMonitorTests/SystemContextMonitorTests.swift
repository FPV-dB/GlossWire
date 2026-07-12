import Testing
@testable import LiveConnectionsMonitorCore

@Test func systemContextParsesVPNRouteAndSleepAssertions() {
    let interfaces = """
    en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST>
    utun4: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST>
    utun8: flags=8050<POINTOPOINT,RUNNING,MULTICAST>
    """
    #expect(SystemContextProvider.vpnInterfaces(interfaces) == ["utun4"])
    #expect(SystemContextProvider.defaultInterface("  interface: utun4\n") == "utun4")
    #expect(SystemContextProvider.connectedVPNServices("* (Connected)  ABC \"Work VPN\" [VPN:IPSec]\n* (Disconnected) DEF \"Old VPN\"") == ["Work VPN"])
    let assertions = """
    PreventUserIdleSystemSleep    1
       pid 42(coreaudiod): [0x1] PreventUserIdleSystemSleep named: audio
    PreventSystemSleep            0
    """
    let parsed = SystemContextProvider.sleepPreventers(assertions)
    #expect(parsed.contains { $0.contains("coreaudiod") })
    #expect(!parsed.contains { $0.contains("PreventSystemSleep            0") })
}
